from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from ueef_spec_workflow.controller import Controller
from ueef_spec_workflow.errors import WorkflowError
from ueef_spec_workflow.model import TaskGraph
from ueef_spec_workflow.orchestration import HostResult
from ueef_spec_workflow.scheduler import Scheduler
from ueef_spec_workflow.state import ExecutionState, StateStore
from ueef_spec_workflow.verification import VerificationReport

from .helpers import graph, graph_data, task


def v2_graph(*tasks):
    data = graph_data(*tasks)
    data.update(
        {
            "schemaVersion": 2,
            "generatedFrom": "tasks.md",
            "sourceDigest": "1" * 64,
            "routeBinding": {
                "routeDigest": "2" * 64,
                "executionSpecDigest": "3" * 64,
            },
        }
    )
    return TaskGraph.from_dict(data)


class ImmediateRuntime:
    capabilities = frozenset({"dispatch", "poll", "heartbeat", "close"})

    def __init__(self) -> None:
        self.contracts = {}
        self.closed = []
        self.cancelled = []

    def dispatch(self, contract):
        self.contracts.setdefault(contract.attempt_id, contract)
        return "handle-" + contract.attempt_id

    def poll(self, handle) -> HostResult | None:
        contract = self.contracts[handle.removeprefix("handle-")]
        return HostResult.for_contract(
            contract, "complete", evidence='{"AC-001":"verified"}'
        )

    def heartbeat(self, handle):
        pass

    def cancel(self, handle):
        self.cancelled.append(handle)

    def close(self, handle):
        self.closed.append(handle)


class ControllerTests(unittest.TestCase):
    def test_partial_host_failure_retries_with_a_new_attempt_and_converges(self) -> None:
        class RetryRuntime(ImmediateRuntime):
            def __init__(self):
                super().__init__()
                self.poll_count = 0

            def poll(self, handle):
                self.poll_count += 1
                contract = self.contracts[handle.removeprefix("handle-")]
                if self.poll_count == 1:
                    return HostResult.for_contract(contract, "fail", error="transient host failure")
                return HostResult.for_contract(
                    contract, "complete", evidence='{"AC-001":"retry verified"}'
                )

        subject = graph(task("TASK-001", retryLimit=1))
        runtime = RetryRuntime()
        with tempfile.TemporaryDirectory() as directory:
            store = StateStore(Path(directory) / "state.json")
            store.save(ExecutionState.new(subject))
            report = Controller(subject, runtime).run(store)
            self.assertEqual(report.status, "DONE")
            self.assertEqual(report.dispatched, 2)
            self.assertEqual(len(runtime.contracts), 2)
            self.assertEqual(store.load(subject).tasks["TASK-001"].attempts, 2)

    def test_cancel_active_uses_declared_lifecycle_and_blocks_state(self) -> None:
        subject = graph(task("TASK-001"))
        runtime = ImmediateRuntime()
        runtime.capabilities = frozenset({"dispatch", "poll", "cancel", "close"})
        with tempfile.TemporaryDirectory() as directory:
            store = StateStore(Path(directory) / "state.json")
            state = ExecutionState.new(subject)
            state.reserve_wave([("TASK-001", "worker-1")], 1)
            state.tasks["TASK-001"].host_handle = "handle-1"
            state.transition(subject, "TASK-001", "start", worker="worker-1")
            store.save(state)
            cancelled = Controller(subject, runtime).cancel_active(store, reason="operator stop")
            self.assertEqual(cancelled, ("TASK-001",))
            self.assertEqual(runtime.cancelled, ["handle-1"])
            self.assertEqual(store.load(subject).overall_status, "BLOCKED")

    def test_v2_completion_waits_for_independent_verifier(self) -> None:
        class PassingVerifier:
            def verify(self, graph, state):
                return VerificationReport(True, "independent tests passed", "4" * 64)

        subject = v2_graph(task("TASK-001"))
        with tempfile.TemporaryDirectory() as directory:
            store = StateStore(Path(directory) / "state.json")
            store.save(ExecutionState.new(subject))
            pending = Controller(subject, ImmediateRuntime()).run(store)
            self.assertEqual(pending.status, "VERIFYING")
            passed = Controller(subject, ImmediateRuntime(), verifier=PassingVerifier()).run(store)
            self.assertEqual(passed.status, "DONE")
            self.assertEqual(store.load(subject).verification_status, "PASS")

    def test_failed_verifier_requires_replan(self) -> None:
        class FailingVerifier:
            def verify(self, graph, state):
                return VerificationReport(False, "finding F-1", "5" * 64, findings=("F-1",))

        subject = v2_graph(task("TASK-001"))
        with tempfile.TemporaryDirectory() as directory:
            store = StateStore(Path(directory) / "state.json")
            store.save(ExecutionState.new(subject))
            report = Controller(subject, ImmediateRuntime(), verifier=FailingVerifier()).run(store)
            self.assertEqual(report.status, "NEEDS_REPLAN")

    def test_controller_dispatches_applies_and_closes_to_done(self) -> None:
        subject = graph(task("TASK-001"), task("TASK-002", dependsOn=["TASK-001"]))
        runtime = ImmediateRuntime()
        with tempfile.TemporaryDirectory() as directory:
            store = StateStore(Path(directory) / "state.json")
            store.save(ExecutionState.new(subject))
            report = Controller(subject, runtime).run(store)
            self.assertEqual(report.status, "DONE")
            self.assertEqual(report.dispatched, 2)
            self.assertEqual(report.applied, 2)
            self.assertEqual(len(runtime.closed), 2)

    def test_reserved_crash_boundary_reuses_attempt_idempotently(self) -> None:
        subject = graph(task("TASK-001"))
        runtime = ImmediateRuntime()
        with tempfile.TemporaryDirectory() as directory:
            store = StateStore(Path(directory) / "state.json")
            state = ExecutionState.new(subject)
            decision = Scheduler(subject).decide(state)
            state.reserve_wave([("TASK-001", "worker-1")], decision.desired_workers)
            attempt = state.tasks["TASK-001"].attempt_id
            store.save(state)
            report = Controller(subject, runtime).run(store)
            self.assertEqual(report.status, "DONE")
            self.assertIn(attempt, runtime.contracts)

    def test_pending_host_poll_persists_lease_heartbeat(self) -> None:
        class PendingOnceRuntime(ImmediateRuntime):
            def __init__(self):
                super().__init__()
                self.polls = 0

            def poll(self, handle):
                self.polls += 1
                if self.polls == 1:
                    return None
                return super().poll(handle)

        subject = graph(task("TASK-001"))
        runtime = PendingOnceRuntime()
        with tempfile.TemporaryDirectory() as directory:
            store = StateStore(Path(directory) / "state.json")
            store.save(ExecutionState.new(subject))
            report = Controller(subject, runtime).run(store)
            self.assertEqual(report.status, "DONE")
            self.assertEqual(store.load(subject).tasks["TASK-001"].lease_renewals, 1)

    def test_controller_rejects_untruthful_or_insufficient_capabilities(self) -> None:
        subject = graph(task("TASK-001"))
        runtime = ImmediateRuntime()
        runtime.capabilities = frozenset({"dispatch", "invented"})
        with self.assertRaisesRegex(WorkflowError, "unknown capabilities"):
            Controller(subject, runtime)
        runtime.capabilities = frozenset({"dispatch"})
        with self.assertRaisesRegex(WorkflowError, "requires dispatch and poll"):
            Controller(subject, runtime)


if __name__ == "__main__":
    unittest.main()
