from __future__ import annotations

import json
import tempfile
import unittest
from datetime import UTC, datetime, timedelta
from pathlib import Path

from ueef_spec_workflow.errors import StateConflictError, WorkflowError
from ueef_spec_workflow.scheduler import Scheduler
from ueef_spec_workflow.state import ExecutionState, StateStore, TaskStatus

from .helpers import graph, task


class ExecutionStateTests(unittest.TestCase):
    def test_operator_pause_resume_is_idempotent_and_preserves_identity(self) -> None:
        subject = graph(task("TASK-001"))
        state = ExecutionState.new(subject)
        execution_id = state.execution_id
        state.pause("operator maintenance")
        revision = state.revision
        state.pause("operator maintenance")
        self.assertEqual(state.revision, revision)
        self.assertEqual(state.overall_status, "PAUSED")
        self.assertEqual(Scheduler(subject).decide(state).tasks, ())
        state.resume()
        resumed_revision = state.revision
        state.resume()
        self.assertEqual(state.revision, resumed_revision)
        self.assertEqual(state.overall_status, "READY")
        self.assertEqual(state.execution_id, execution_id)

    def test_lease_heartbeat_is_bounded_and_expiry_reclaims_with_new_fence(self) -> None:
        subject = graph(task("TASK-001", retryLimit=2))
        state = ExecutionState.new(subject)
        start = datetime(2026, 8, 9, tzinfo=UTC)
        state.reserve_wave([("TASK-001", "worker-1")], 1, lease_seconds=10, now=start)
        first = state.tasks["TASK-001"]
        old_attempt = first.attempt_id
        old_fence = first.fencing_token
        for seconds in (1, 2, 3):
            state.heartbeat(
                "TASK-001",
                old_attempt or "",
                old_fence or "",
                now=start + timedelta(seconds=seconds),
                extend_seconds=10,
            )
        with self.assertRaisesRegex(WorkflowError, "renewal limit"):
            state.heartbeat(
                "TASK-001",
                old_attempt or "",
                old_fence or "",
                now=start + timedelta(seconds=4),
                extend_seconds=10,
            )
        self.assertEqual(
            state.reclaim_expired(subject, now=start + timedelta(seconds=14)),
            ("TASK-001",),
        )
        self.assertEqual(state.tasks["TASK-001"].status, TaskStatus.READY)
        state.reserve_wave(
            [("TASK-001", "worker-2")],
            1,
            lease_seconds=10,
            now=start + timedelta(seconds=15),
        )
        current = state.tasks["TASK-001"]
        self.assertEqual(current.lease_generation, 2)
        self.assertNotEqual(current.attempt_id, old_attempt)
        self.assertNotEqual(current.fencing_token, old_fence)

    def test_pause_freezes_active_lease_until_resume(self) -> None:
        subject = graph(task("TASK-001"))
        state = ExecutionState.new(subject)
        start = datetime(2026, 8, 9, tzinfo=UTC)
        state.reserve_wave([("TASK-001", "worker-1")], 1, lease_seconds=10, now=start)
        state.pause("maintenance", now=start + timedelta(seconds=2))
        self.assertEqual(state.reclaim_expired(subject, now=start + timedelta(hours=1)), ())
        state.resume(now=start + timedelta(seconds=102))
        self.assertEqual(
            state.tasks["TASK-001"].lease_expires_at,
            "2026-08-09T00:01:50Z",
        )
        self.assertEqual(state.reclaim_expired(subject, now=start + timedelta(seconds=109)), ())
        self.assertEqual(
            state.reclaim_expired(subject, now=start + timedelta(seconds=110)),
            ("TASK-001",),
        )

    def test_expired_lease_cannot_be_renewed(self) -> None:
        subject = graph(task("TASK-001"))
        state = ExecutionState.new(subject)
        start = datetime(2026, 8, 9, tzinfo=UTC)
        state.reserve_wave([("TASK-001", "worker-1")], 1, lease_seconds=1, now=start)
        run = state.tasks["TASK-001"]
        with self.assertRaisesRegex(WorkflowError, "expired"):
            state.heartbeat(
                "TASK-001",
                run.attempt_id or "",
                run.fencing_token or "",
                now=start + timedelta(seconds=1),
            )

    def test_changed_write_scope_invalidates_verification(self) -> None:
        subject = graph(task("TASK-001", writeSet=["src/api"]), task("TASK-002", writeSet=["docs"]))
        state = ExecutionState.new(subject)
        state.record_verification(
            passed=True, evidence="independent", diff_digest="a" * 64, independent=True
        )
        affected = state.invalidate_verification(subject, ["src/api/routes.py"])
        self.assertEqual(affected, ("TASK-001",))
        self.assertEqual(state.verification_status, "PENDING")
        self.assertIsNone(state.verification_evidence)

    def test_non_independent_verification_is_rejected(self) -> None:
        subject = graph(task("TASK-001"))
        state = ExecutionState.new(subject)
        with self.assertRaisesRegex(WorkflowError, "independent"):
            state.record_verification(
                passed=True, evidence="self report", diff_digest="a" * 64, independent=False
            )

    def test_initial_state_marks_roots_ready_and_dependents_pending(self) -> None:
        subject = graph(task("TASK-001"), task("TASK-002", dependsOn=["TASK-001"]))
        state = ExecutionState.new(subject)
        self.assertEqual(state.tasks["TASK-001"].status, TaskStatus.READY)
        self.assertEqual(state.tasks["TASK-002"].status, TaskStatus.PENDING)

    def test_completion_requires_evidence(self) -> None:
        subject = graph(task("TASK-001"))
        state = ExecutionState.new(subject)
        state.reserve_wave([("TASK-001", "worker-1")], 1)
        state.transition(subject, "TASK-001", "start", worker="worker-1")
        with self.assertRaisesRegex(WorkflowError, "requires non-empty evidence"):
            state.transition(subject, "TASK-001", "complete")

    def test_bounded_retry_then_terminal_failure_blocks_dependents(self) -> None:
        subject = graph(
            task("TASK-001", retryLimit=1),
            task("TASK-002", dependsOn=["TASK-001"]),
        )
        state = ExecutionState.new(subject)
        state.reserve_wave([("TASK-001", "worker-1")], 1)
        state.transition(subject, "TASK-001", "start", worker="worker-1")
        state.transition(subject, "TASK-001", "fail", error="first")
        self.assertEqual(state.tasks["TASK-001"].status, TaskStatus.READY)
        state.reserve_wave([("TASK-001", "worker-2")], 1)
        state.transition(subject, "TASK-001", "start", worker="worker-2")
        state.transition(subject, "TASK-001", "fail", error="second")
        self.assertEqual(state.tasks["TASK-001"].status, TaskStatus.FAILED)
        self.assertEqual(state.tasks["TASK-002"].status, TaskStatus.BLOCKED)
        self.assertEqual(state.tasks["TASK-002"].block_kind, "dependency")

    def test_manual_block_can_be_unblocked(self) -> None:
        subject = graph(task("TASK-001"))
        state = ExecutionState.new(subject)
        state.transition(subject, "TASK-001", "block", error="missing input")
        self.assertEqual(state.tasks["TASK-001"].status, TaskStatus.BLOCKED)
        state.transition(subject, "TASK-001", "unblock")
        self.assertEqual(state.tasks["TASK-001"].status, TaskStatus.READY)

    def test_reserved_task_is_worker_bound_and_releasable(self) -> None:
        subject = graph(task("TASK-001"))
        state = ExecutionState.new(subject)
        state.reserve_wave([("TASK-001", "worker-1")], 1)
        self.assertEqual(state.tasks["TASK-001"].status, TaskStatus.RESERVED)
        with self.assertRaisesRegex(WorkflowError, "reserved for"):
            state.transition(subject, "TASK-001", "start", worker="worker-2")
        state.transition(subject, "TASK-001", "release", error="dispatch failed")
        self.assertEqual(state.tasks["TASK-001"].status, TaskStatus.READY)

    def test_worker_cannot_own_two_active_tasks(self) -> None:
        subject = graph(task("TASK-001"), task("TASK-002"))
        state = ExecutionState.new(subject)
        state.reserve_wave([("TASK-001", "worker-1")], 1)
        state.transition(subject, "TASK-001", "start", worker="worker-1")
        with self.assertRaisesRegex(WorkflowError, "already has active work"):
            state.reserve_wave([("TASK-002", "worker-1")], 1)

    def test_transition_text_limits_are_enforced(self) -> None:
        subject = graph(task("TASK-001"))
        state = ExecutionState.new(subject)
        with self.assertRaisesRegex(WorkflowError, "worker cannot exceed"):
            state.reserve_wave([("TASK-001", "w" * 129)], 1)
        state.reserve_wave([("TASK-001", "worker-1")], 1)
        state.transition(subject, "TASK-001", "start", worker="worker-1")
        with self.assertRaisesRegex(WorkflowError, "evidence cannot exceed"):
            state.transition(subject, "TASK-001", "complete", evidence="x" * 4001)

    def test_atomic_store_resume_and_revision_conflict(self) -> None:
        subject = graph(task("TASK-001"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"
            store = StateStore(path)
            state = ExecutionState.new(subject)
            store.save(state)
            resumed = store.load(subject)
            resumed.reserve_wave([("TASK-001", "worker-1")], 1)
            store.save(resumed, expected_revision=0)
            with self.assertRaises(StateConflictError):
                store.save(resumed, expected_revision=0)
            self.assertEqual(json.loads(path.read_text(encoding="utf-8"))["revision"], 1)

            path.unlink()
            with self.assertRaisesRegex(StateConflictError, "found missing state"):
                store.save(resumed, expected_revision=1)
            self.assertFalse(path.exists())

    def test_start_requires_a_live_reservation(self) -> None:
        subject = graph(task("TASK-001"))
        state = ExecutionState.new(subject)
        with self.assertRaisesRegex(WorkflowError, "must be RESERVED"):
            state.transition(subject, "TASK-001", "start", worker="worker-1")
        expired = datetime(2020, 1, 1, tzinfo=UTC)
        state.reserve_wave([("TASK-001", "worker-1")], 1, lease_seconds=1, now=expired)
        revision = state.revision
        with self.assertRaisesRegex(WorkflowError, "lease expired"):
            state.transition(subject, "TASK-001", "start", worker="worker-1")
        self.assertEqual(state.revision, revision)
        self.assertEqual(state.tasks["TASK-001"].status, TaskStatus.RESERVED)

    def test_token_ledger_uses_estimate_and_fails_closed_on_budget_overrun(self) -> None:
        subject = graph(task("TASK-001", effortPoints=3), tokenBudget=1000)
        state = ExecutionState.new(subject)
        state.reserve_wave([("TASK-001", "worker-1")], 1)
        attempt_id = state.tasks["TASK-001"].attempt_id or ""
        state.transition(subject, "TASK-001", "start", worker="worker-1")
        state.transition(subject, "TASK-001", "complete", evidence="verified", tokens=None)
        self.assertEqual(state.tokens_consumed, subject.task_map["TASK-001"].estimated_tokens)
        self.assertEqual(state.token_ledger, {attempt_id: state.tokens_consumed})
        self.assertEqual(state.tasks["TASK-001"].status, TaskStatus.FAILED)
        round_trip = ExecutionState.from_dict(state.to_dict(), subject)
        self.assertEqual(round_trip.token_ledger, state.token_ledger)

    def test_manual_block_on_dependent_survives_dependency_refresh_and_round_trip(self) -> None:
        subject = graph(task("TASK-001"), task("TASK-002", dependsOn=["TASK-001"]))
        state = ExecutionState.new(subject)
        state.transition(subject, "TASK-002", "block", error="operator hold")
        state.transition(subject, "TASK-001", "block", error="upstream hold")
        state.refresh(subject)
        restored = ExecutionState.from_dict(state.to_dict(), subject)
        restored.refresh(subject)
        dependent = restored.tasks["TASK-002"]
        self.assertEqual((dependent.status, dependent.block_kind, dependent.last_error), (
            TaskStatus.BLOCKED, "manual", "operator hold"
        ))

    def test_status_specific_invariants_reject_impossible_persisted_state(self) -> None:
        subject = graph(task("TASK-001"))
        mutations = (
            {"status": "DONE", "completedAt": None, "evidence": []},
            {"status": "BLOCKED", "blockKind": None, "lastError": None},
            {"status": "READY", "assignedWorker": "ghost"},
        )
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                data = ExecutionState.new(subject).to_dict()
                data["tasks"]["TASK-001"].update(mutation)
                with self.assertRaises(WorkflowError):
                    ExecutionState.from_dict(data, subject)

    def test_graph_drift_refuses_resume(self) -> None:
        original = graph(task("TASK-001"))
        changed = graph(task("TASK-001"), task("TASK-002"))
        data = ExecutionState.new(original).to_dict()
        with self.assertRaisesRegex(WorkflowError, "different task graph"):
            ExecutionState.from_dict(data, changed)

    def test_schema_v2_rejects_malformed_verification_metadata(self) -> None:
        subject = graph(task("TASK-001"))
        mutations = {
            "executionId": "not-a-uuid",
            "verificationStatus": "TRUST_ME",
            "verificationDiffDigest": "short",
            "verificationInvalidatedTasks": ["TASK-MISSING"],
            "verificationRounds": True,
            "convergenceHistory": ["not-a-digest"],
        }
        for field, value in mutations.items():
            with self.subTest(field=field):
                data = ExecutionState.new(subject).to_dict()
                data[field] = value
                with self.assertRaises(WorkflowError):
                    ExecutionState.from_dict(data, subject)

    def test_schema_v2_rejects_incomplete_active_lease_identity(self) -> None:
        subject = graph(task("TASK-001"))
        state = ExecutionState.new(subject)
        state.reserve_wave([("TASK-001", "worker-1")], 1)
        data = state.to_dict()
        data["tasks"]["TASK-001"]["fencingToken"] = "stale"
        with self.assertRaisesRegex(WorkflowError, "256-bit"):
            ExecutionState.from_dict(data, subject)


if __name__ == "__main__":
    unittest.main()
