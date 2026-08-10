"""Verifier-gap convergence with additive graph and state migration."""

from __future__ import annotations

import hashlib
import json
from copy import deepcopy
from typing import Any

from .compiler import compile_plan
from .errors import WorkflowError
from .model import TaskGraph
from .state import ExecutionState, TaskRun

_MAX_CONVERGENCE_ROUNDS = 3


def _finding_digest(findings: Any) -> str:
    payload = json.dumps(findings, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def replan_canonical(
    markdown: str,
    graph: TaskGraph,
    state: ExecutionState,
    findings: Any,
    route: Any,
) -> tuple[str, TaskGraph, ExecutionState]:
    """Append verifier gaps to the canonical plan, compile it, and migrate finished state."""

    if state.overall_status != "NEEDS_REPLAN":
        raise WorkflowError("canonical replan requires NEEDS_REPLAN state")
    if len(state.convergence_history) >= _MAX_CONVERGENCE_ROUNDS:
        raise WorkflowError("convergence round limit reached")
    if not isinstance(findings, dict) or findings.get("schemaVersion") not in {1, 2}:
        raise WorkflowError("convergence findings schemaVersion must be 1 or 2")
    raw = findings.get("tasks")
    if not isinstance(raw, list) or not raw:
        raise WorkflowError("convergence findings require a non-empty tasks array")
    digest = _finding_digest(findings)
    if digest in state.convergence_history:
        raise WorkflowError("convergence made no progress: findings fingerprint repeated")
    known = set(graph.task_map)
    blocks: list[str] = []
    for index, item in enumerate(raw):
        if not isinstance(item, dict):
            raise WorkflowError(f"convergence tasks[{index}] must be an object")
        source_task_id = item.get("id")
        title = item.get("title")
        source = item.get("sourceEvidence")
        if (
            not isinstance(source_task_id, str)
            or not source_task_id.strip()
            or not isinstance(title, str)
            or not title.strip()
            or not isinstance(source, str)
            or not source.strip()
        ):
            raise WorkflowError(
                f"convergence tasks[{index}] requires id, title, and sourceEvidence"
            )
        task_id = source_task_id if source_task_id.startswith("TASK-") else f"TASK-{source_task_id}"
        if task_id in known:
            raise WorkflowError(f"convergence task already exists: {task_id}")
        known.add(task_id)

        def values(
            name: str,
            default: list[str],
            record: dict[str, Any] = item,
            current_task_id: str = task_id,
        ) -> str:
            value = record.get(name, default)
            if not isinstance(value, list) or any(not isinstance(entry, str) for entry in value):
                raise WorkflowError(
                    f"{current_task_id}.{name} must be an array of strings"
                )
            return ", ".join(value) if value else "none"

        acceptance = item.get("acceptance", ["AC-007"])
        if not isinstance(acceptance, list) or any(
            not isinstance(entry, str) or not entry.strip() for entry in acceptance
        ):
            raise WorkflowError(f"{task_id}.acceptance must be an array of strings")
        evidence_contract = json.dumps(
            {criterion.strip(): source.strip() for criterion in acceptance},
            ensure_ascii=False,
            separators=(",", ":"),
        )

        blocks.append(
            "\n".join(
                [
                    f"- [ ] {task_id} {title.strip()}",
                    f"  - Requirements: {values('requirements', ['REQ-007'])}",
                    f"  - Acceptance: {', '.join(acceptance)}",
                    "  - Delegation: verifier",
                    f"  - Allowed write set: {values('writeSet', [])}",
                    f"  - Forbidden paths: {values('forbiddenPaths', [])}",
                    f"  - Depends on: {values('dependsOn', list(graph.task_map))}",
                    f"  - Capabilities: {values('capabilities', ['verification'])}",
                    f"  - Effort points: {item.get('effortPoints', 1)}",
                    f"  - Risk: {item.get('risk', 2)}",
                    f"  - Priority: {item.get('priority', 100)}",
                    f"  - Parallel safe: {str(item.get('parallelSafe', False)).lower()}",
                    f"  - Read only: {str(item.get('readOnly', True)).lower()}",
                    f"  - Evidence: {evidence_contract}",
                    "  - Done when: independent verifier evidence passes",
                ]
            )
        )
    amended_markdown = markdown.rstrip() + "\n" + "\n".join(blocks) + "\n"
    compiled = TaskGraph.from_dict(compile_plan(amended_markdown, graph.workflow_id, route))
    migrated = ExecutionState.new(compiled)
    for task_id in graph.task_map:
        migrated.tasks[task_id] = deepcopy(state.tasks[task_id])
    migrated.tokens_consumed = state.tokens_consumed
    migrated.token_ledger = deepcopy(state.token_ledger)
    migrated.created_at = state.created_at
    migrated.revision = state.revision + 1
    migrated.convergence_history = [*state.convergence_history, digest]
    migrated.verification_status = "PENDING"
    migrated.verification_evidence = None
    migrated.verification_diff_digest = None
    migrated.refresh(compiled)
    return amended_markdown, compiled, migrated


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
    migrated.token_ledger = deepcopy(state.token_ledger)
    migrated.team_size_target = state.team_size_target
    migrated.created_at = state.created_at
    migrated.revision = state.revision + 1
    migrated.refresh(new_graph)
    return new_graph, migrated
