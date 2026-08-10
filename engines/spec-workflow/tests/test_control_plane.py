from __future__ import annotations

import unittest
from typing import Any

from ueef_spec_workflow.control_plane import aggregate_control_status
from ueef_spec_workflow.errors import WorkflowError
from ueef_spec_workflow.model import TaskGraph
from ueef_spec_workflow.state import ExecutionState, TaskStatus


def graph() -> TaskGraph:
    return TaskGraph.from_dict(
        {
            "schemaVersion": 1,
            "workflowId": "control-plane-test",
            "tasks": [{"id": "TASK", "title": "Test"}],
        }
    )


class ControlPlaneTests(unittest.TestCase):
    def setUp(self) -> None:
        self.graph = graph()
        self.state = ExecutionState.new(self.graph)
        self.hosts = {"codex": "VERIFIED_RUNTIME"}

    def status(self, **kwargs: Any) -> dict[str, Any]:
        return aggregate_control_status(
            self.graph,
            self.state,
            kwargs.pop("host_status", self.hosts),
            kwargs.pop("approval_statuses", []),
            **kwargs,
        )

    def test_priority_states_remain_distinct(self) -> None:
        cases = [
            ({"supply_chain_result": {"status": "FAILED"}}, "FAILED"),
            ({"approval_statuses": [{"status": "EXPIRED"}]}, "BLOCKED"),
            ({"approval_statuses": [{"status": "PENDING"}]}, "WAITING_APPROVAL"),
            ({"host_status": {"codex": "UNAVAILABLE"}}, "UNAVAILABLE"),
            ({"supply_chain_result": {"status": "VERIFYING"}}, "VERIFYING"),
            ({"supply_chain_result": {"status": "DEGRADED"}}, "DEGRADED"),
        ]
        for arguments, expected in cases:
            with self.subTest(expected=expected):
                self.assertEqual(self.status(**arguments)["status"], expected)

    def test_failed_has_priority_but_signals_are_not_collapsed(self) -> None:
        result = self.status(
            host_status="UNAVAILABLE",
            approval_statuses=[{"status": "PENDING"}],
            supply_chain_result={"status": "FAILED"},
        )
        self.assertEqual(result["status"], "FAILED")
        self.assertEqual(
            result["signals"],
            {
                "failed": True,
                "blocked": False,
                "waitingApproval": True,
                "unavailable": True,
                "verifying": False,
                "degraded": False,
            },
        )

    def test_verified_done_and_optional_portfolio_failure(self) -> None:
        self.state.tasks["TASK"].status = TaskStatus.DONE
        done = self.status(portfolio_result={"status": "DONE", "statuses": {"core": "DONE"}})
        self.assertEqual(done["status"], "DONE")
        degraded = self.status(
            portfolio_result={
                "status": "DONE",
                "statuses": {"core": "DONE", "optional": "FAILED"},
            }
        )
        self.assertEqual(degraded["status"], "DEGRADED")

    def test_unverified_portfolio_is_verifying_and_degraded_signal_is_retained(self) -> None:
        result = self.status(
            portfolio_result={"status": "BLOCKED", "statuses": {"feature": "UNVERIFIED"}}
        )
        self.assertEqual(result["status"], "BLOCKED")
        self.assertTrue(result["signals"]["verifying"])
        self.assertTrue(result["signals"]["degraded"])

    def test_graph_state_identity_and_input_shapes_fail_closed(self) -> None:
        self.state.graph_digest = "0" * 64
        with self.assertRaisesRegex(WorkflowError, "identity"):
            self.status()
        self.state.graph_digest = self.graph.digest
        with self.assertRaisesRegex(WorkflowError, "approval statuses"):
            self.status(approval_statuses=[{}])
        with self.assertRaisesRegex(WorkflowError, "supply-chain"):
            self.status(supply_chain_result={})


if __name__ == "__main__":
    unittest.main()
