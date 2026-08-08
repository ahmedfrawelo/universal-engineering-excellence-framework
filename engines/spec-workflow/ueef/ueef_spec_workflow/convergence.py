"""Verifier-gap convergence with additive graph and state migration."""

from __future__ import annotations

from copy import deepcopy
from typing import Any

from .errors import WorkflowError
from .model import TaskGraph
from .state import ExecutionState, TaskRun


def converge(
    graph: TaskGraph, state: ExecutionState, findings: Any
) -> tuple[TaskGraph, ExecutionState]:
    if not isinstance(findings, dict) or findings.get("schemaVersion") != 1:
        raise WorkflowError("convergence findings schemaVersion must be 1")
    raw = findings.get("tasks")
    if not isinstance(raw, list) or not raw:
        raise WorkflowError("convergence findings require a non-empty tasks array")
    existing = graph.to_dict()
    known = set(graph.task_map)
    additions: list[dict[str, Any]] = []
    for index, item in enumerate(raw):
        if not isinstance(item, dict):
            raise WorkflowError(f"convergence tasks[{index}] must be an object")
        evidence = item.get("sourceEvidence")
        if not isinstance(evidence, str) or not evidence.strip():
            raise WorkflowError(f"convergence tasks[{index}] requires sourceEvidence")
        task = dict(item)
        task_id = task.get("id")
        if not isinstance(task_id, str):
            raise WorkflowError(f"convergence tasks[{index}] requires a string id")
        if task_id in known:
            raise WorkflowError(f"convergence task already exists: {task_id}")
        additions.append(task)
        known.add(task_id)
    candidate = deepcopy(existing)
    candidate["tasks"].extend(additions)
    new_graph = TaskGraph.from_dict(candidate)
    migrated = ExecutionState.new(new_graph)
    migrated.tasks = {
        task.id: deepcopy(state.tasks[task.id]) if task.id in state.tasks else TaskRun()
        for task in new_graph.tasks
    }
    migrated.tokens_consumed = state.tokens_consumed
    migrated.team_size_target = state.team_size_target
    migrated.created_at = state.created_at
    migrated.revision = state.revision + 1
    migrated.refresh(new_graph)
    return new_graph, migrated
