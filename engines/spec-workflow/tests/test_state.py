from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from ueef_spec_workflow.errors import StateConflictError, WorkflowError
from ueef_spec_workflow.state import ExecutionState, StateStore, TaskStatus

from .helpers import graph, task


class ExecutionStateTests(unittest.TestCase):
    def test_initial_state_marks_roots_ready_and_dependents_pending(self) -> None:
        subject = graph(task("TASK-001"), task("TASK-002", dependsOn=["TASK-001"]))
        state = ExecutionState.new(subject)
        self.assertEqual(state.tasks["TASK-001"].status, TaskStatus.READY)
        self.assertEqual(state.tasks["TASK-002"].status, TaskStatus.PENDING)

    def test_completion_requires_evidence(self) -> None:
        subject = graph(task("TASK-001"))
        state = ExecutionState.new(subject)
        state.transition(subject, "TASK-001", "start", worker="worker-1")
        with self.assertRaisesRegex(WorkflowError, "requires non-empty evidence"):
            state.transition(subject, "TASK-001", "complete")

    def test_bounded_retry_then_terminal_failure_blocks_dependents(self) -> None:
        subject = graph(
            task("TASK-001", retryLimit=1),
            task("TASK-002", dependsOn=["TASK-001"]),
        )
        state = ExecutionState.new(subject)
        state.transition(subject, "TASK-001", "start", worker="worker-1")
        state.transition(subject, "TASK-001", "fail", error="first")
        self.assertEqual(state.tasks["TASK-001"].status, TaskStatus.READY)
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
        state.transition(subject, "TASK-001", "start", worker="worker-1")
        with self.assertRaisesRegex(WorkflowError, "already assigned"):
            state.transition(subject, "TASK-002", "start", worker="worker-1")

    def test_transition_text_limits_are_enforced(self) -> None:
        subject = graph(task("TASK-001"))
        state = ExecutionState.new(subject)
        with self.assertRaisesRegex(WorkflowError, "worker cannot exceed"):
            state.transition(subject, "TASK-001", "start", worker="w" * 129)
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
            resumed.transition(subject, "TASK-001", "start", worker="worker-1")
            store.save(resumed, expected_revision=0)
            with self.assertRaises(StateConflictError):
                store.save(resumed, expected_revision=0)
            self.assertEqual(json.loads(path.read_text(encoding="utf-8"))["revision"], 1)

    def test_graph_drift_refuses_resume(self) -> None:
        original = graph(task("TASK-001"))
        changed = graph(task("TASK-001"), task("TASK-002"))
        data = ExecutionState.new(original).to_dict()
        with self.assertRaisesRegex(WorkflowError, "different task graph"):
            ExecutionState.from_dict(data, changed)


if __name__ == "__main__":
    unittest.main()
