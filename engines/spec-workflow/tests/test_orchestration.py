from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from ueef_spec_workflow.adapters import get_adapter
from ueef_spec_workflow.errors import WorkflowError
from ueef_spec_workflow.orchestration import HostResult, Orchestrator, RecordedHostRuntime
from ueef_spec_workflow.scheduler import Scheduler
from ueef_spec_workflow.state import ExecutionState, StateStore, TaskStatus

from .helpers import graph, task


class SuccessfulRuntime:
    def execute(self, contract):
        return HostResult(
            task_id=contract.task_id,
            worker=contract.worker,
            outcome="complete",
            evidence="acceptance verified",
            tokens=100,
        )


class OrchestrationTests(unittest.TestCase):
    def test_host_adapters_emit_distinct_transport_metadata(self) -> None:
        subject = graph(task("TASK-001"))
        state = ExecutionState.new(subject)
        decision = Scheduler(subject).decide(state)
        codex = get_adapter("codex").build(subject, decision)[0]
        claude = get_adapter("claude").build(subject, decision)[0]
        self.assertEqual(codex.transport, "codex-thread")
        self.assertEqual(claude.transport, "claude-agent-team")
        self.assertEqual(codex.result_protocol, "ueef-host-result/v1")

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
                return HostResult("TASK-999", contract.worker, "complete", "evidence")

        subject = graph(task("TASK-001"))
        with self.assertRaisesRegex(WorkflowError, "does not match"):
            Orchestrator(subject).run_wave(ExecutionState.new(subject), WrongRuntime())

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
        runtime = RecordedHostRuntime(
            {
                "schemaVersion": 1,
                "results": [
                    {
                        "taskId": "TASK-001",
                        "worker": "worker-1",
                        "outcome": "complete",
                        "evidence": "verified",
                        "tokens": 7,
                    }
                ],
            }
        )
        report = Orchestrator(subject).run_wave(ExecutionState.new(subject), runtime)
        self.assertEqual(report.results[0].tokens, 7)

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
            runtime = RecordedHostRuntime(
                {
                    "schemaVersion": 1,
                    "results": [
                        {
                            "taskId": "TASK-001",
                            "worker": "worker-1",
                            "outcome": "complete",
                            "evidence": "verified",
                        }
                    ],
                }
            )
            results = Orchestrator(subject).apply_persisted_results(store, runtime)
            self.assertEqual(len(results), 1)
            self.assertEqual(store.load(subject).overall_status, "DONE")


if __name__ == "__main__":
    unittest.main()
