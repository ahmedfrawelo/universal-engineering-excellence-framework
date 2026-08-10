from __future__ import annotations

import unittest

from ueef_spec_workflow.adapters import get_adapter
from ueef_spec_workflow.errors import WorkflowError
from ueef_spec_workflow.model import TaskGraph
from ueef_spec_workflow.scheduler import Scheduler
from ueef_spec_workflow.state import ExecutionState

from .helpers import graph_data, task


class DispatchPolicyTests(unittest.TestCase):
    @staticmethod
    def _contract(*, shell_policy: str, allowed: list[str]):
        data = graph_data(task("TASK-001"))
        data["policy"]["shellPolicy"] = shell_policy
        data["policy"]["allowedShellCommands"] = allowed
        subject = TaskGraph.from_dict(data)
        state = ExecutionState.new(subject)
        decision = Scheduler(subject).decide(state)
        state.reserve_wave(
            [(item.task_id, item.worker) for item in decision.tasks],
            decision.desired_workers,
        )
        return get_adapter("generic").build(subject, decision, state)[0]

    def test_deny_policy_is_bound_into_contract_and_fails_closed(self) -> None:
        contract = self._contract(shell_policy="deny", allowed=[])
        self.assertEqual(contract.to_dict()["shellPolicy"], "deny")
        self.assertEqual(contract.to_dict()["allowedShellCommands"], [])
        with self.assertRaisesRegex(WorkflowError, "denies shell"):
            contract.assert_shell_command_allowed("git status")

    def test_allowlist_requires_an_exact_contract_bound_command(self) -> None:
        contract = self._contract(shell_policy="allowlist", allowed=["git status --short"])
        contract.assert_shell_command_allowed("git status --short")
        with self.assertRaisesRegex(WorkflowError, "not present"):
            contract.assert_shell_command_allowed("git status")
        self.assertIn("exact commands", contract.prompt)


if __name__ == "__main__":
    unittest.main()
