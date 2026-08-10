"""Explicit, non-destructive v1-to-v2 workflow migration."""

from __future__ import annotations

import hashlib
import json
from copy import deepcopy
from pathlib import Path
from typing import Any

from .compiler import compile_plan
from .errors import WorkflowError
from .model import TaskGraph
from .state import ExecutionState, TaskStatus


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def migrate_v1(
    markdown: str, route: Any, graph_document: Any, state_document: Any
) -> tuple[TaskGraph, ExecutionState]:
    if not isinstance(graph_document, dict) or graph_document.get("schemaVersion") != 1:
        raise WorkflowError("migration input graph must be schema version 1")
    if not isinstance(state_document, dict) or state_document.get("schemaVersion") != 1:
        raise WorkflowError("migration input state must be schema version 1")
    old_graph = TaskGraph.from_dict(graph_document)
    old_state = ExecutionState.from_dict(state_document, old_graph)
    active = [
        task_id
        for task_id, run in old_state.tasks.items()
        if run.status in {TaskStatus.RESERVED, TaskStatus.RUNNING}
    ]
    if active:
        raise WorkflowError(
            "active v1 attempts cannot be migrated without fencing; release or finish them first: "
            + ", ".join(sorted(active))
        )
    new_graph = TaskGraph.from_dict(compile_plan(markdown, old_graph.workflow_id, route))
    if set(new_graph.task_map) != set(old_graph.task_map):
        raise WorkflowError("canonical tasks must match the v1 graph task IDs before migration")
    migrated = ExecutionState.new(new_graph)
    migrated.tasks = {task_id: deepcopy(old_state.tasks[task_id]) for task_id in new_graph.task_map}
    migrated.tokens_consumed = old_state.tokens_consumed
    migrated.team_size_target = 0
    migrated.created_at = old_state.created_at
    migrated.revision = old_state.revision + 1
    migrated.verification_status = "PENDING"
    migrated.refresh(new_graph, touch=False)
    return new_graph, migrated


def write_migration_bundle(
    backup: Path,
    graph_bytes: bytes,
    state_bytes: bytes,
    new_graph: TaskGraph,
    new_state: ExecutionState,
) -> None:
    if backup.exists():
        raise WorkflowError(f"migration backup already exists: {backup}")
    backup.mkdir(parents=True)
    (backup / "task-graph.v1.json").write_bytes(graph_bytes)
    (backup / "execution-state.v1.json").write_bytes(state_bytes)
    manifest = {
        "schemaVersion": 1,
        "rollback": "restore task-graph.v1.json and execution-state.v1.json together",
        "original": {
            "graphSha256": sha256_bytes(graph_bytes),
            "stateSha256": sha256_bytes(state_bytes),
        },
        "migrated": {
            "graphDigest": new_graph.digest,
            "executionId": new_state.execution_id,
        },
    }
    (backup / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n"
    )
