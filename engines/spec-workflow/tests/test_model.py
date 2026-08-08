from __future__ import annotations

import unittest

from ueef_spec_workflow.errors import WorkflowError
from ueef_spec_workflow.model import TaskGraph, normalize_scope_path, scopes_overlap

from .helpers import graph, graph_data, task


class TaskGraphModelTests(unittest.TestCase):
    def test_valid_graph_has_stable_digest_and_critical_path(self) -> None:
        subject = graph(
            task("TASK-001", effortPoints=2),
            task("TASK-002", dependsOn=["TASK-001"], effortPoints=3),
            task("TASK-003", dependsOn=["TASK-001"], effortPoints=1),
        )
        self.assertEqual(subject.digest, TaskGraph.from_dict(subject.to_dict()).digest)
        self.assertEqual(
            subject.downstream_weights(),
            {"TASK-001": 5, "TASK-002": 3, "TASK-003": 1},
        )

    def test_unknown_dependency_is_rejected(self) -> None:
        with self.assertRaisesRegex(WorkflowError, "unknown dependencies"):
            graph(task("TASK-001", dependsOn=["TASK-404"]))

    def test_cycle_reports_the_path(self) -> None:
        with self.assertRaisesRegex(
            WorkflowError, "TASK-001 -> TASK-002 -> TASK-001"
        ):
            graph(
                task("TASK-001", dependsOn=["TASK-002"]),
                task("TASK-002", dependsOn=["TASK-001"]),
            )

    def test_duplicate_ids_are_rejected(self) -> None:
        with self.assertRaisesRegex(WorkflowError, "duplicates: TASK-001"):
            TaskGraph.from_dict(graph_data(task("TASK-001"), task("TASK-001")))

    def test_path_normalization_and_overlap(self) -> None:
        self.assertEqual(normalize_scope_path(".\\src\\api\\", "writeSet"), "src/api")
        self.assertTrue(scopes_overlap(("src",), ("src/api/routes.py",)))
        self.assertTrue(scopes_overlap(("src/API",), ("src/api/routes.py",)))
        self.assertFalse(scopes_overlap(("src/api",), ("src/web",)))
        with self.assertRaisesRegex(WorkflowError, "traversal"):
            normalize_scope_path("../secrets", "writeSet")

    def test_read_only_task_cannot_declare_writes(self) -> None:
        with self.assertRaisesRegex(WorkflowError, "readOnly"):
            graph(task("TASK-001", readOnly=True))

    def test_write_and_forbidden_scopes_cannot_overlap(self) -> None:
        with self.assertRaisesRegex(WorkflowError, "overlaps forbiddenPaths"):
            graph(task("TASK-001", writeSet=["src"], forbiddenPaths=["src/private"]))

    def test_normalized_scope_duplicates_are_rejected(self) -> None:
        with self.assertRaisesRegex(WorkflowError, "duplicate normalized paths"):
            graph(task("TASK-001", writeSet=["src/API", "src/api"]))

    def test_shell_allowlist_must_be_explicit(self) -> None:
        data = graph_data(task("TASK-001"))
        data["policy"]["allowedShellCommands"] = ["git status"]
        with self.assertRaisesRegex(WorkflowError, "must be empty"):
            TaskGraph.from_dict(data)

    def test_graph_size_limits_are_enforced(self) -> None:
        with self.assertRaisesRegex(WorkflowError, "more than 500"):
            TaskGraph.from_dict(
                graph_data(*(task(f"TASK-{index:03d}") for index in range(501)))
            )
        with self.assertRaisesRegex(WorkflowError, "cannot exceed 512"):
            graph(task("TASK-001", title="x" * 513))


if __name__ == "__main__":
    unittest.main()
