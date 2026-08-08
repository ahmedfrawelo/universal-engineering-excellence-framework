from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from ueef_spec_workflow.errors import WorkflowError
from ueef_spec_workflow.state import ExecutionState, StateStore, TaskStatus
from ueef_spec_workflow.team_manager import TeamManager

from .helpers import graph, task


def workers(*items: dict[str, object]) -> tuple:
    return TeamManager.parse_workers({"schemaVersion": 1, "workers": list(items)})


class TeamManagerTests(unittest.TestCase):
    def test_capability_matching_assigns_real_available_worker(self) -> None:
        subject = graph(
            task("TASK-001", capabilities=["backend"], writeSet=["src/backend"]),
            task("TASK-002", capabilities=["frontend"], writeSet=["src/frontend"]),
        )
        report = TeamManager(subject, "codex").plan(
            ExecutionState.new(subject),
            workers(
                {"id": "backend-worker", "capabilities": ["backend"]},
                {"id": "frontend-worker", "capabilities": ["frontend"]},
            ),
        )
        self.assertEqual(
            {contract.worker for contract in report.contracts},
            {"backend-worker", "frontend-worker"},
        )

    def test_incompatible_worker_emits_wait_action_not_contract(self) -> None:
        subject = graph(task("TASK-001", capabilities=["security"]))
        report = TeamManager(subject).plan(
            ExecutionState.new(subject), workers({"id": "backend", "capabilities": ["backend"]})
        )
        self.assertEqual(report.contracts, ())
        self.assertEqual(report.actions[-1].kind, "WAIT_FOR_WORKER")

    def test_failed_attempt_emits_durable_reroute_guidance(self) -> None:
        subject = graph(task("TASK-001", capabilities=["backend"]))
        state = ExecutionState.new(subject)
        state.transition(subject, "TASK-001", "start", worker="previous")
        state.transition(subject, "TASK-001", "fail", worker="previous", error="host lost")
        with tempfile.TemporaryDirectory() as directory:
            store = StateStore(Path(directory) / "state.json")
            store.save(state)
            report = TeamManager(subject).manage_persisted(
                store, workers({"id": "replacement", "capabilities": ["backend"]})
            )
            self.assertIn("REROUTE", [action.kind for action in report.actions])
            events = [
                json.loads(line)
                for line in store.events_path.read_text(encoding="utf-8").splitlines()
            ]
            self.assertEqual(events[-1]["kind"], "team-management-cycle")
            self.assertEqual(events[-1]["actions"][0]["kind"], "REROUTE")

    def test_verifier_and_integration_wait_for_prior_work(self) -> None:
        subject = graph(
            task("TASK-001", capabilities=["backend"]),
            task("VERIFY-001", capabilities=["verifier"], readOnly=True, writeSet=[]),
            task("INTEGRATE-001", capabilities=["integration"]),
        )
        state = ExecutionState.new(subject)
        report = TeamManager(subject).plan(
            state,
            workers(
                {"id": "backend", "capabilities": ["backend"]},
                {"id": "reviewer", "capabilities": ["verifier"]},
                {"id": "integrator", "capabilities": ["integration"]},
            ),
        )
        self.assertEqual([contract.task_id for contract in report.contracts], ["TASK-001"])
        self.assertEqual(
            {action.task_id for action in report.actions if action.kind == "DEFER_PHASE"},
            {"VERIFY-001", "INTEGRATE-001"},
        )
        state.transition(subject, "TASK-001", "start", worker="backend")
        state.transition(subject, "TASK-001", "complete", worker="backend", evidence="done")
        report = TeamManager(subject).plan(
            state,
            workers(
                {"id": "reviewer", "capabilities": ["verifier"]},
                {"id": "integrator", "capabilities": ["integration"]},
            ),
        )
        self.assertEqual([contract.task_id for contract in report.contracts], ["VERIFY-001"])
        state.transition(subject, "VERIFY-001", "start", worker="reviewer")
        state.transition(subject, "VERIFY-001", "complete", worker="reviewer", evidence="reviewed")
        report = TeamManager(subject).plan(
            state, workers({"id": "integrator", "capabilities": ["integration"]})
        )
        self.assertEqual([contract.task_id for contract in report.contracts], ["INTEGRATE-001"])

    def test_commit_reserves_selected_real_worker(self) -> None:
        subject = graph(task("TASK-001", capabilities=["backend"]))
        with tempfile.TemporaryDirectory() as directory:
            store = StateStore(Path(directory) / "state.json")
            store.save(ExecutionState.new(subject))
            TeamManager(subject).manage_persisted(
                store, workers({"id": "backend", "capabilities": ["backend"]}), commit=True
            )
            self.assertEqual(store.load(subject).tasks["TASK-001"].status, TaskStatus.RESERVED)
            self.assertEqual(store.load(subject).tasks["TASK-001"].assigned_worker, "backend")

    def test_rejects_invalid_worker_catalog(self) -> None:
        with self.assertRaisesRegex(WorkflowError, "schemaVersion"):
            TeamManager.parse_workers({"workers": []})


if __name__ == "__main__":
    unittest.main()
