from __future__ import annotations

import unittest

from ueef_spec_workflow.convergence import converge
from ueef_spec_workflow.errors import WorkflowError
from ueef_spec_workflow.state import ExecutionState, TaskStatus

from .helpers import graph, task


class ConvergenceTests(unittest.TestCase):
    def test_additive_migration_preserves_finished_work(self) -> None:
        subject = graph(task("TASK-001"))
        state = ExecutionState.new(subject)
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
