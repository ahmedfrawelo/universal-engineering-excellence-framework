from __future__ import annotations

import unittest

from ueef_spec_workflow.compiler import compile_plan
from ueef_spec_workflow.convergence import converge, replan_canonical
from ueef_spec_workflow.errors import WorkflowError
from ueef_spec_workflow.model import TaskGraph
from ueef_spec_workflow.state import ExecutionState, TaskStatus

from .helpers import graph, task
from .test_compiler import TASKS, route


class ConvergenceTests(unittest.TestCase):
    def test_v2_replan_updates_canonical_plan_and_migrates_finished_state(self) -> None:
        subject = TaskGraph.from_dict(compile_plan(TASKS, "demo-flow", route()))
        state = ExecutionState.new(subject)
        for task_id in ("TASK-001", "TASK-002"):
            state.reserve_wave([(task_id, f"worker-{task_id[-1]}")], 1)
            state.transition(subject, task_id, "start", worker=f"worker-{task_id[-1]}")
            state.transition(subject, task_id, "complete", evidence="done")
        state.record_verification(
            passed=False, evidence="finding F-1", diff_digest="f" * 64, independent=True
        )
        findings = {
            "schemaVersion": 2,
            "tasks": [
                {
                    "id": "GAP-001",
                    "title": "Close verifier gap",
                    "sourceEvidence": "finding F-1",
                }
            ],
        }
        markdown, amended, migrated = replan_canonical(TASKS, subject, state, findings, route())
        self.assertIn("- [ ] TASK-GAP-001 Close verifier gap", markdown)
        self.assertIn("TASK-GAP-001", amended.task_map)
        self.assertEqual(migrated.tasks["TASK-001"].status, TaskStatus.DONE)
        self.assertEqual(migrated.tasks["TASK-GAP-001"].status, TaskStatus.READY)
        self.assertEqual(migrated.verification_status, "PENDING")

    def test_v2_replan_rejects_repeated_findings_without_progress(self) -> None:
        subject = TaskGraph.from_dict(compile_plan(TASKS, "demo-flow", route()))
        state = ExecutionState.new(subject)
        for task_id in ("TASK-001", "TASK-002"):
            state.tasks[task_id].status = TaskStatus.DONE
        state.verification_status = "FAIL"
        findings = {
            "schemaVersion": 2,
            "tasks": [{"id": "GAP-001", "title": "Gap", "sourceEvidence": "F-1"}],
        }
        from ueef_spec_workflow.convergence import _finding_digest

        state.convergence_history = [_finding_digest(findings)]
        with self.assertRaisesRegex(WorkflowError, "no progress"):
            replan_canonical(TASKS, subject, state, findings, route())

    def test_additive_migration_preserves_finished_work(self) -> None:
        subject = graph(task("TASK-001"))
        state = ExecutionState.new(subject)
        state.reserve_wave([("TASK-001", "worker-1")], 1)
        state.transition(subject, "TASK-001", "start", worker="worker-1")
        state.transition(subject, "TASK-001", "complete", evidence="tests passed")
        amended, migrated = converge(
            subject,
            state,
            {
                "schemaVersion": 1,
                "tasks": [
                    {
                        "id": "GAP-001",
                        "title": "Close verifier gap",
                        "dependsOn": ["TASK-001"],
                        "acceptance": ["gap evidence"],
                        "readOnly": True,
                        "sourceEvidence": "verifier finding F-1",
                    }
                ],
            },
        )
        self.assertEqual(amended.task_map["GAP-001"].depends_on, ("TASK-001",))
        self.assertEqual(amended.task_map["GAP-001"].source_evidence, "verifier finding F-1")
        self.assertEqual(migrated.tasks["TASK-001"].status, TaskStatus.DONE)
        self.assertEqual(migrated.tasks["GAP-001"].status, TaskStatus.READY)
        self.assertEqual(migrated.tokens_consumed, state.tokens_consumed)
        self.assertEqual(migrated.token_ledger, state.token_ledger)
        restored = ExecutionState.from_dict(migrated.to_dict(), amended)
        self.assertEqual(restored.token_ledger, state.token_ledger)

    def test_gap_requires_traceable_source_evidence(self) -> None:
        subject = graph(task("TASK-001"))
        with self.assertRaisesRegex(WorkflowError, "sourceEvidence"):
            converge(
                subject,
                ExecutionState.new(subject),
                {"schemaVersion": 1, "tasks": [{"id": "GAP-001", "title": "gap"}]},
            )


if __name__ == "__main__":
    unittest.main()
