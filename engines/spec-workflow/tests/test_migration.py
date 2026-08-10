from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from ueef_spec_workflow.compiler import compile_plan
from ueef_spec_workflow.errors import WorkflowError
from ueef_spec_workflow.migration import migrate_v1, write_migration_bundle
from ueef_spec_workflow.model import TaskGraph
from ueef_spec_workflow.state import ExecutionState, TaskStatus

from .test_compiler import TASKS, route


def v1_fixture():
    compiled = compile_plan(TASKS, "demo-flow", route())
    graph_data = {
        "schemaVersion": 1,
        "workflowId": compiled["workflowId"],
        "policy": compiled["policy"],
        "tasks": compiled["tasks"],
    }
    graph = TaskGraph.from_dict(graph_data)
    state = ExecutionState.new(graph)
    state.schema_version = 1
    document = state.to_dict()
    document["schemaVersion"] = 1
    return graph_data, document


class MigrationTests(unittest.TestCase):
    def test_v1_migration_is_non_destructive_and_writes_rollback_hashes(self) -> None:
        graph_document, state_document = v1_fixture()
        new_graph, new_state = migrate_v1(TASKS, route(), graph_document, state_document)
        self.assertEqual(new_graph.schema_version, 2)
        self.assertEqual(new_state.verification_status, "PENDING")
        graph_bytes = (json.dumps(graph_document) + "\n").encode()
        state_bytes = (json.dumps(state_document) + "\n").encode()
        with tempfile.TemporaryDirectory() as directory:
            backup = Path(directory) / "backup"
            write_migration_bundle(backup, graph_bytes, state_bytes, new_graph, new_state)
            self.assertEqual((backup / "task-graph.v1.json").read_bytes(), graph_bytes)
            manifest = json.loads((backup / "manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(len(manifest["original"]["graphSha256"]), 64)

    def test_active_v1_attempt_is_rejected_because_it_has_no_safe_fence(self) -> None:
        graph_document, state_document = v1_fixture()
        graph = TaskGraph.from_dict(graph_document)
        state = ExecutionState.from_dict(state_document, graph)
        state.tasks["TASK-001"].status = TaskStatus.RUNNING
        state.tasks["TASK-001"].assigned_worker = "legacy-worker"
        state_document = state.to_dict()
        state_document["schemaVersion"] = 1
        with self.assertRaisesRegex(WorkflowError, "cannot be migrated without fencing"):
            migrate_v1(TASKS, route(), graph_document, state_document)


if __name__ == "__main__":
    unittest.main()
