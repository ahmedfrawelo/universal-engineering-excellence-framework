"""Validated task-graph model shared by scheduling and persistence."""

from __future__ import annotations

import hashlib
import json
import os
import re
from collections.abc import Iterable
from dataclasses import dataclass, field
from pathlib import PurePosixPath
from typing import Any

from .errors import WorkflowError

_WORKFLOW_ID = re.compile(r"^[a-z0-9][a-z0-9-]{1,62}$")
_TASK_ID = re.compile(r"^[A-Z][A-Z0-9_-]{1,63}$")
_TIERS = frozenset({"T0", "T1", "T2", "T3", "T4"})
_BUDGET_MODES = frozenset({"minimal", "bounded", "expanded"})
_MAX_TASKS = 500
_MAX_GRAPH_BYTES = 5 * 1024 * 1024
_MAX_LIST_ITEMS = 256
_MAX_TEXT_LENGTH = 512


def _as_string_list(value: Any, field_name: str) -> tuple[str, ...]:
    if value is None:
        return ()
    if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
        raise WorkflowError(f"{field_name} must be an array of strings")
    if len(value) > _MAX_LIST_ITEMS:
        raise WorkflowError(f"{field_name} cannot contain more than {_MAX_LIST_ITEMS} items")
    stripped = tuple(item.strip() for item in value)
    if any(not item for item in stripped):
        raise WorkflowError(f"{field_name} cannot contain empty strings")
    if any(len(item) > _MAX_TEXT_LENGTH for item in stripped):
        raise WorkflowError(
            f"{field_name} entries cannot exceed {_MAX_TEXT_LENGTH} characters"
        )
    if len(set(stripped)) != len(stripped):
        raise WorkflowError(f"{field_name} cannot contain duplicates")
    return stripped


def normalize_scope_path(value: str, field_name: str) -> str:
    """Normalize a repository-relative ownership path and reject traversal."""

    candidate = value.strip().replace("\\", "/")
    if len(candidate) > _MAX_TEXT_LENGTH:
        raise WorkflowError(f"{field_name} paths cannot exceed {_MAX_TEXT_LENGTH} characters")
    while candidate.startswith("./"):
        candidate = candidate[2:]
    candidate = candidate.rstrip("/")
    if not candidate:
        raise WorkflowError(f"{field_name} cannot contain an empty path")
    if candidate.startswith("/") or re.match(r"^[A-Za-z]:", candidate):
        raise WorkflowError(f"{field_name} paths must be repository-relative: {value!r}")
    parts = PurePosixPath(candidate).parts
    if any(part in {"", ".", ".."} for part in parts):
        raise WorkflowError(f"{field_name} contains traversal or an invalid segment: {value!r}")
    if any(any(mark in part for mark in "*?[]") for part in parts):
        raise WorkflowError(f"{field_name} paths must be literal ownership roots: {value!r}")
    return "/".join(parts)


def scopes_overlap(left: Iterable[str], right: Iterable[str]) -> bool:
    """Return whether two sets of literal repository roots can touch."""

    for first in left:
        for second in right:
            first = first.casefold()
            second = second.casefold()
            if first == second or first.startswith(second + "/") or second.startswith(first + "/"):
                return True
    return False


@dataclass(frozen=True)
class WorkflowPolicy:
    """Execution limits supplied by UEEF policy rather than the upstream engine."""

    tier: str = "T2"
    max_workers: int = 2
    token_budget_mode: str = "bounded"
    token_budget: int | None = None
    retry_limit: int = 1
    shell_policy: str = "deny"
    allowed_shell_commands: tuple[str, ...] = ()

    @classmethod
    def from_dict(cls, data: Any) -> WorkflowPolicy:
        if not isinstance(data, dict):
            raise WorkflowError("policy must be an object")
        tier = data.get("tier", "T2")
        if tier not in _TIERS:
            raise WorkflowError(f"policy.tier must be one of {sorted(_TIERS)}")
        max_workers = data.get("maxWorkers", 2)
        if (
            isinstance(max_workers, bool)
            or not isinstance(max_workers, int)
            or not 1 <= max_workers <= 16
        ):
            raise WorkflowError("policy.maxWorkers must be an integer from 1 through 16")
        budget_mode = data.get("tokenBudgetMode", "bounded")
        if budget_mode not in _BUDGET_MODES:
            raise WorkflowError(
                f"policy.tokenBudgetMode must be one of {sorted(_BUDGET_MODES)}"
            )
        token_budget = data.get("tokenBudget")
        if token_budget is not None and (
            isinstance(token_budget, bool)
            or not isinstance(token_budget, int)
            or token_budget < 1
        ):
            raise WorkflowError("policy.tokenBudget must be a positive integer when supplied")
        retry_limit = data.get("retryLimit", 1)
        if (
            isinstance(retry_limit, bool)
            or not isinstance(retry_limit, int)
            or not 0 <= retry_limit <= 5
        ):
            raise WorkflowError("policy.retryLimit must be an integer from 0 through 5")
        shell_policy = data.get("shellPolicy", "deny")
        if shell_policy not in {"deny", "allowlist"}:
            raise WorkflowError("policy.shellPolicy must be deny or allowlist")
        allowed = _as_string_list(
            data.get("allowedShellCommands", []), "policy.allowedShellCommands"
        )
        if shell_policy == "deny" and allowed:
            raise WorkflowError("allowedShellCommands must be empty when shellPolicy is deny")
        if shell_policy == "allowlist" and not allowed:
            raise WorkflowError(
                "shellPolicy allowlist requires at least one allowedShellCommands entry"
            )
        return cls(
            tier=tier,
            max_workers=max_workers,
            token_budget_mode=budget_mode,
            token_budget=token_budget,
            retry_limit=retry_limit,
            shell_policy=shell_policy,
            allowed_shell_commands=allowed,
        )

    def to_dict(self) -> dict[str, Any]:
        result: dict[str, Any] = {
            "tier": self.tier,
            "maxWorkers": self.max_workers,
            "tokenBudgetMode": self.token_budget_mode,
            "retryLimit": self.retry_limit,
            "shellPolicy": self.shell_policy,
            "allowedShellCommands": list(self.allowed_shell_commands),
        }
        if self.token_budget is not None:
            result["tokenBudget"] = self.token_budget
        return result


@dataclass(frozen=True)
class TaskSpec:
    """One independently ownable unit in the execution graph."""

    id: str
    title: str
    depends_on: tuple[str, ...] = ()
    requirements: tuple[str, ...] = ()
    acceptance: tuple[str, ...] = ()
    write_set: tuple[str, ...] = ()
    forbidden_paths: tuple[str, ...] = ()
    capabilities: tuple[str, ...] = ()
    effort_points: int = 1
    risk: int = 0
    priority: int = 0
    parallel_safe: bool = False
    read_only: bool = False
    retry_limit: int | None = None

    @classmethod
    def from_dict(cls, data: Any, index: int) -> TaskSpec:
        if not isinstance(data, dict):
            raise WorkflowError(f"tasks[{index}] must be an object")
        task_id = data.get("id")
        if not isinstance(task_id, str) or not _TASK_ID.fullmatch(task_id):
            raise WorkflowError(
                f"tasks[{index}].id must match {_TASK_ID.pattern!r}; got {task_id!r}"
            )
        title = data.get("title")
        if not isinstance(title, str) or not title.strip():
            raise WorkflowError(f"{task_id}.title must be a non-empty string")
        if len(title.strip()) > _MAX_TEXT_LENGTH:
            raise WorkflowError(
                f"{task_id}.title cannot exceed {_MAX_TEXT_LENGTH} characters"
            )
        depends_on = _as_string_list(data.get("dependsOn", []), f"{task_id}.dependsOn")
        if task_id in depends_on:
            raise WorkflowError(f"{task_id} cannot depend on itself")
        write_set = tuple(
            normalize_scope_path(path, f"{task_id}.writeSet")
            for path in _as_string_list(data.get("writeSet", []), f"{task_id}.writeSet")
        )
        forbidden_paths = tuple(
            normalize_scope_path(path, f"{task_id}.forbiddenPaths")
            for path in _as_string_list(
                data.get("forbiddenPaths", []), f"{task_id}.forbiddenPaths"
            )
        )
        if len({path.casefold() for path in write_set}) != len(write_set):
            raise WorkflowError(f"{task_id}.writeSet contains duplicate normalized paths")
        if len({path.casefold() for path in forbidden_paths}) != len(forbidden_paths):
            raise WorkflowError(f"{task_id}.forbiddenPaths contains duplicate normalized paths")
        if scopes_overlap(write_set, forbidden_paths):
            raise WorkflowError(f"{task_id}.writeSet overlaps forbiddenPaths")
        read_only = data.get("readOnly", False)
        parallel_safe = data.get("parallelSafe", False)
        if not isinstance(read_only, bool) or not isinstance(parallel_safe, bool):
            raise WorkflowError(f"{task_id}.readOnly and parallelSafe must be booleans")
        if read_only and write_set:
            raise WorkflowError(f"{task_id} is readOnly but declares a writeSet")
        effort = data.get("effortPoints", 1)
        if isinstance(effort, bool) or not isinstance(effort, int) or not 1 <= effort <= 21:
            raise WorkflowError(f"{task_id}.effortPoints must be an integer from 1 through 21")
        risk = data.get("risk", 0)
        if isinstance(risk, bool) or not isinstance(risk, int) or not 0 <= risk <= 3:
            raise WorkflowError(f"{task_id}.risk must be an integer from 0 through 3")
        priority = data.get("priority", 0)
        if (
            isinstance(priority, bool)
            or not isinstance(priority, int)
            or not -100 <= priority <= 100
        ):
            raise WorkflowError(f"{task_id}.priority must be an integer from -100 through 100")
        retry_limit = data.get("retryLimit")
        if retry_limit is not None and (
            isinstance(retry_limit, bool)
            or not isinstance(retry_limit, int)
            or not 0 <= retry_limit <= 5
        ):
            raise WorkflowError(f"{task_id}.retryLimit must be an integer from 0 through 5")
        return cls(
            id=task_id,
            title=title.strip(),
            depends_on=depends_on,
            requirements=_as_string_list(data.get("requirements", []), f"{task_id}.requirements"),
            acceptance=_as_string_list(data.get("acceptance", []), f"{task_id}.acceptance"),
            write_set=write_set,
            forbidden_paths=forbidden_paths,
            capabilities=_as_string_list(data.get("capabilities", []), f"{task_id}.capabilities"),
            effort_points=effort,
            risk=risk,
            priority=priority,
            parallel_safe=parallel_safe,
            read_only=read_only,
            retry_limit=retry_limit,
        )

    def to_dict(self) -> dict[str, Any]:
        result: dict[str, Any] = {
            "id": self.id,
            "title": self.title,
            "dependsOn": list(self.depends_on),
            "requirements": list(self.requirements),
            "acceptance": list(self.acceptance),
            "writeSet": list(self.write_set),
            "forbiddenPaths": list(self.forbidden_paths),
            "capabilities": list(self.capabilities),
            "effortPoints": self.effort_points,
            "risk": self.risk,
            "priority": self.priority,
            "parallelSafe": self.parallel_safe,
            "readOnly": self.read_only,
        }
        if self.retry_limit is not None:
            result["retryLimit"] = self.retry_limit
        return result

    def effective_retry_limit(self, policy: WorkflowPolicy) -> int:
        return policy.retry_limit if self.retry_limit is None else self.retry_limit

    @property
    def estimated_tokens(self) -> int:
        return self.effort_points * 500


@dataclass(frozen=True)
class TaskGraph:
    """Acyclic, validated workflow graph."""

    workflow_id: str
    tasks: tuple[TaskSpec, ...]
    policy: WorkflowPolicy = field(default_factory=WorkflowPolicy)
    schema_version: int = 1

    @classmethod
    def from_dict(cls, data: Any) -> TaskGraph:
        if not isinstance(data, dict):
            raise WorkflowError("task graph must be a JSON object")
        schema_version = data.get("schemaVersion")
        if schema_version != 1:
            raise WorkflowError("schemaVersion must be 1")
        workflow_id = data.get("workflowId")
        if not isinstance(workflow_id, str) or not _WORKFLOW_ID.fullmatch(workflow_id):
            raise WorkflowError(
                f"workflowId must match {_WORKFLOW_ID.pattern!r}; got {workflow_id!r}"
            )
        raw_tasks = data.get("tasks")
        if not isinstance(raw_tasks, list) or not raw_tasks:
            raise WorkflowError("tasks must be a non-empty array")
        if len(raw_tasks) > _MAX_TASKS:
            raise WorkflowError(f"tasks cannot contain more than {_MAX_TASKS} entries")
        tasks = tuple(TaskSpec.from_dict(item, index) for index, item in enumerate(raw_tasks))
        ids = [task.id for task in tasks]
        if len(set(ids)) != len(ids):
            duplicates = sorted({task_id for task_id in ids if ids.count(task_id) > 1})
            raise WorkflowError(f"task IDs must be unique; duplicates: {', '.join(duplicates)}")
        known = set(ids)
        for task in tasks:
            missing = sorted(set(task.depends_on) - known)
            if missing:
                raise WorkflowError(f"{task.id} has unknown dependencies: {', '.join(missing)}")
        graph = cls(
            workflow_id=workflow_id,
            tasks=tasks,
            policy=WorkflowPolicy.from_dict(data.get("policy", {})),
            schema_version=schema_version,
        )
        graph._validate_acyclic()
        return graph

    @classmethod
    def from_json_file(cls, path: str) -> TaskGraph:
        try:
            size = os.stat(path).st_size
            if size > _MAX_GRAPH_BYTES:
                raise WorkflowError(
                    f"task graph exceeds the {_MAX_GRAPH_BYTES}-byte input limit"
                )
            with open(path, encoding="utf-8-sig") as handle:
                return cls.from_dict(json.load(handle))
        except json.JSONDecodeError as exc:
            raise WorkflowError(f"invalid task graph JSON: {exc}") from exc

    def _validate_acyclic(self) -> None:
        dependencies = {task.id: task.depends_on for task in self.tasks}
        visiting: list[str] = []
        visited: set[str] = set()

        def visit(task_id: str) -> None:
            if task_id in visiting:
                cycle = visiting[visiting.index(task_id) :] + [task_id]
                raise WorkflowError(f"dependency cycle detected: {' -> '.join(cycle)}")
            if task_id in visited:
                return
            visiting.append(task_id)
            for dependency in dependencies[task_id]:
                visit(dependency)
            visiting.pop()
            visited.add(task_id)

        for task in self.tasks:
            visit(task.id)

    @property
    def task_map(self) -> dict[str, TaskSpec]:
        return {task.id: task for task in self.tasks}

    def to_dict(self) -> dict[str, Any]:
        return {
            "schemaVersion": self.schema_version,
            "workflowId": self.workflow_id,
            "policy": self.policy.to_dict(),
            "tasks": [task.to_dict() for task in self.tasks],
        }

    @property
    def digest(self) -> str:
        encoded = json.dumps(
            self.to_dict(), ensure_ascii=False, sort_keys=True, separators=(",", ":")
        ).encode("utf-8")
        return hashlib.sha256(encoded).hexdigest()

    def downstream_weights(self) -> dict[str, int]:
        """Return critical-path effort from each task through its dependents."""

        dependents: dict[str, list[str]] = {task.id: [] for task in self.tasks}
        for task in self.tasks:
            for dependency in task.depends_on:
                dependents[dependency].append(task.id)
        task_map = self.task_map
        cache: dict[str, int] = {}

        def weight(task_id: str) -> int:
            if task_id not in cache:
                tail = max((weight(item) for item in dependents[task_id]), default=0)
                cache[task_id] = task_map[task_id].effort_points + tail
            return cache[task_id]

        return {task.id: weight(task.id) for task in self.tasks}
