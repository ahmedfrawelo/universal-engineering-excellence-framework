from __future__ import annotations

import json
import tempfile
import unittest
from dataclasses import replace
from datetime import UTC, datetime
from pathlib import Path

from ueef_spec_workflow.adapters import get_adapter
from ueef_spec_workflow.errors import WorkflowError
from ueef_spec_workflow.orchestration import HostResult, Orchestrator, RecordedHostRuntime
from ueef_spec_workflow.scheduler import Scheduler
from ueef_spec_workflow.state import ExecutionState, StateStore, TaskStatus

from .helpers import graph, task


class SuccessfulRuntime:
    def execute(self, contract):
        return HostResult.for_contract(
            contract,
            "complete",
            evidence='{"AC-001":"acceptance verified"}',
            tokens=100,
        )


def receipt(contract, **changes):
    result = HostResult.for_contract(
        contract, "complete", evidence='{"AC-001":"verified"}', tokens=7
    )
    result = replace(result, **changes)
    return {
        "schemaVersion": 2,
        "results": [
            {
                "taskId": result.task_id,
                "worker": result.worker,
                "outcome": result.outcome,
                "evidence": result.evidence,
                "tokens": result.tokens,
                "workflowId": result.workflow_id,
                "executionId": result.execution_id,
                "graphDigest": result.graph_digest,
                "routeDigest": result.route_digest,
                "executionSpecDigest": result.execution_spec_digest,
                "attemptId": result.attempt_id,
                "leaseGeneration": result.lease_generation,
                "fencingToken": result.fencing_token,
            }
        ],
    }


class OrchestrationTests(unittest.TestCase):
    def test_host_adapters_emit_distinct_transport_metadata(self) -> None:
        subject = graph(task("TASK-001"))
        state = ExecutionState.new(subject)
        decision = Scheduler(subject).decide(state)
        state.reserve_wave([(item.task_id, item.worker) for item in decision.tasks], 1)
        codex = get_adapter("codex").build(subject, decision, state)[0]
        claude = get_adapter("claude").build(subject, decision, state)[0]
        self.assertEqual(codex.transport, "codex-thread")
        self.assertEqual(claude.transport, "claude-agent-team")
        self.assertEqual(codex.result_protocol, "ueef-host-result/v2")
        self.assertEqual(
            get_adapter("codex").capabilities, frozenset({"synchronous-dispatch", "receipt-v2"})
        )
        self.assertNotIn("cancel", get_adapter("claude").capabilities)

    def test_controller_runs_a_wave_and_records_evidence(self) -> None:
        subject = graph(task("TASK-001"), task("TASK-002"))
        state = ExecutionState.new(subject)
        report = Orchestrator(subject, "codex").run_wave(state, SuccessfulRuntime())
        self.assertEqual(len(report.results), 2)
        self.assertEqual(state.tokens_consumed, 200)
        self.assertTrue(all(run.status == TaskStatus.DONE for run in state.tasks.values()))

    def test_host_result_must_match_contract(self) -> None:
        class WrongRuntime:
            def execute(self, contract):
                return replace(
                    HostResult.for_contract(
                        contract, "complete", evidence='{"AC-001":"evidence"}'
                    ),
                    task_id="TASK-999",
                )

        subject = graph(task("TASK-001"))
        with self.assertRaisesRegex(WorkflowError, "identity mismatch"):
            Orchestrator(subject).run_wave(ExecutionState.new(subject), WrongRuntime())

    def test_completion_evidence_must_bind_every_acceptance_identifier(self) -> None:
        class UnboundRuntime:
            def execute(self, contract):
                return HostResult.for_contract(
                    contract, "complete", evidence='{"AC-001":"verified"}'
                )

        subject = graph(task("TASK-001", acceptance=["AC-001", "AC-002"]))
        state = ExecutionState.new(subject)
        with self.assertRaisesRegex(WorkflowError, "acceptance mismatch"):
            Orchestrator(subject).run_wave(state, UnboundRuntime())
        self.assertNotEqual(state.tasks["TASK-001"].status, TaskStatus.DONE)

    def test_runtime_exception_becomes_bounded_failure(self) -> None:
        class FailingRuntime:
            def execute(self, contract):
                raise RuntimeError("host unavailable")

        subject = graph(task("TASK-001"))
        state = ExecutionState.new(subject)
        report = Orchestrator(subject).run_wave(state, FailingRuntime())
        self.assertEqual(report.results[0].outcome, "fail")
        self.assertEqual(state.tasks["TASK-001"].status, TaskStatus.READY)

    def test_recorded_runtime_requires_a_matching_contract_result(self) -> None:
        subject = graph(task("TASK-001"))
        with tempfile.TemporaryDirectory() as directory:
            store = StateStore(Path(directory) / "state.json")
            state = ExecutionState.new(subject)
            decision = Scheduler(subject).decide(state)
            state.reserve_wave([("TASK-001", "worker-1")], 1)
            contract = get_adapter("generic").build(subject, decision, state)[0]
            store.save(state)
            results = Orchestrator(subject).apply_persisted_results(
                store, RecordedHostRuntime(receipt(contract))
            )
            self.assertEqual(results[0].tokens, 7)

    def test_persisted_controller_records_every_boundary(self) -> None:
        subject = graph(task("TASK-001"))
        with tempfile.TemporaryDirectory() as directory:
            store = StateStore(Path(directory) / "state.json")
            store.save(ExecutionState.new(subject))
            Orchestrator(subject, "codex").run_persisted_wave(store, SuccessfulRuntime())
            resumed = store.load(subject)
            self.assertEqual(resumed.tasks["TASK-001"].status, TaskStatus.DONE)
            self.assertEqual(resumed.revision, 3)
            lines = store.events_path.read_text(encoding="utf-8").splitlines()
            events = [json.loads(line) for line in lines]
            self.assertEqual(
                [event["kind"] for event in events],
                ["wave-reserved", "task-started", "task-result"],
            )
            self.assertEqual(events[-1]["outcome"], "complete")

    def test_apply_results_preserves_existing_reservation(self) -> None:
        subject = graph(task("TASK-001"))
        with tempfile.TemporaryDirectory() as directory:
            store = StateStore(Path(directory) / "state.json")
            state = ExecutionState.new(subject)
            state.reserve_wave([("TASK-001", "worker-1")], 1)
            store.save(state)
            decision = Scheduler(subject).decide(ExecutionState.new(subject))
            contract = get_adapter("generic").build(subject, decision, state)[0]
            runtime = RecordedHostRuntime(receipt(contract))
            results = Orchestrator(subject).apply_persisted_results(store, runtime)
            self.assertEqual(len(results), 1)
            self.assertEqual(store.load(subject).overall_status, "DONE")

    def test_stale_receipt_is_rejected_without_state_change(self) -> None:
        subject = graph(task("TASK-001"))
        with tempfile.TemporaryDirectory() as directory:
            store = StateStore(Path(directory) / "state.json")
            state = ExecutionState.new(subject)
            decision = Scheduler(subject).decide(state)
            state.reserve_wave([("TASK-001", "worker-1")], 1)
            contract = get_adapter("generic").build(subject, decision, state)[0]
            store.save(state)
            before = store.path.read_bytes()
            stale = RecordedHostRuntime(receipt(contract, fencing_token="0" * 64))
            with self.assertRaisesRegex(WorkflowError, "fencingToken"):
                Orchestrator(subject).apply_persisted_results(store, stale)
            self.assertEqual(store.path.read_bytes(), before)

    def test_expired_receipt_is_rejected_before_host_execution_without_state_change(self) -> None:
        subject = graph(task("TASK-001"))
        with tempfile.TemporaryDirectory() as directory:
            store = StateStore(Path(directory) / "state.json")
            state = ExecutionState.new(subject)
            decision = Scheduler(subject).decide(state)
            state.reserve_wave(
                [("TASK-001", "worker-1")],
                1,
                lease_seconds=1,
                now=datetime(2020, 1, 1, tzinfo=UTC),
            )
            contract = get_adapter("generic").build(subject, decision, state)[0]
            store.save(state)
            before = store.path.read_bytes()
            with self.assertRaisesRegex(WorkflowError, "lease expired"):
                Orchestrator(subject).apply_persisted_results(
                    store, RecordedHostRuntime(receipt(contract))
                )
            self.assertEqual(store.path.read_bytes(), before)

    def test_invalid_persisted_receipt_never_leaves_task_running(self) -> None:
        class InvalidRuntime:
            def execute(self, contract):
                return replace(
                    HostResult.for_contract(
                        contract, "complete", evidence='{"AC-001":"verified"}'
                    ),
                    execution_id="wrong-execution",
                )

        subject = graph(task("TASK-001"))
        with tempfile.TemporaryDirectory() as directory:
            store = StateStore(Path(directory) / "state.json")
            store.save(ExecutionState.new(subject))
            report = Orchestrator(subject).run_persisted_wave(store, InvalidRuntime())
            restored = store.load(subject)
            self.assertEqual(report.results[0].outcome, "fail")
            self.assertNotEqual(restored.tasks["TASK-001"].status, TaskStatus.RUNNING)


if __name__ == "__main__":
    unittest.main()
