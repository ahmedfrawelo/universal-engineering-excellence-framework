"""Durable execution state and guarded task transitions."""

from __future__ import annotations

import json
import os
import tempfile
import time
from contextlib import contextmanager
from dataclasses import dataclass, field
from datetime import UTC, datetime
from enum import StrEnum
from pathlib import Path
from typing import Any

from .errors import StateConflictError, WorkflowError
from .model import TaskGraph

_MAX_STATE_BYTES = 10 * 1024 * 1024
_MAX_EVIDENCE_ITEMS = 100
_MAX_EVIDENCE_LENGTH = 4000
_MAX_ERROR_LENGTH = 4000
_MAX_WORKER_LENGTH = 128
_MAX_EVENT_BYTES = 64 * 1024


def utc_now() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


@contextmanager
def _exclusive_file_lock(path: Path, timeout_seconds: float = 5.0):
    """Take a small cross-platform lock around compare-and-replace state writes."""

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a+b") as handle:
        if handle.seek(0, os.SEEK_END) == 0:
            handle.write(b"\0")
            handle.flush()
        deadline = time.monotonic() + timeout_seconds
        while True:
            try:
                handle.seek(0)
                if os.name == "nt":
                    import msvcrt

                    msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
                else:
                    import fcntl

                    fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except OSError as exc:
                if time.monotonic() >= deadline:
                    raise StateConflictError(f"timed out waiting for state lock: {path}") from exc
                time.sleep(0.05)
        try:
            yield
        finally:
            handle.seek(0)
            if os.name == "nt":
                import msvcrt

                msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                import fcntl

                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


class TaskStatus(StrEnum):
    PENDING = "PENDING"
    READY = "READY"
    RESERVED = "RESERVED"
    RUNNING = "RUNNING"
    BLOCKED = "BLOCKED"
    DONE = "DONE"
    FAILED = "FAILED"


@dataclass
class TaskRun:
    status: TaskStatus = TaskStatus.PENDING
    attempts: int = 0
    assigned_worker: str | None = None
    started_at: str | None = None
    completed_at: str | None = None
    last_error: str | None = None
    block_kind: str | None = None
    evidence: list[str] = field(default_factory=list)

    @classmethod
    def from_dict(cls, data: Any, task_id: str) -> TaskRun:
        if not isinstance(data, dict):
            raise WorkflowError(f"state.tasks.{task_id} must be an object")
        try:
            status = TaskStatus(data.get("status"))
        except ValueError as exc:
            raise WorkflowError(f"state.tasks.{task_id}.status is invalid") from exc
        attempts = data.get("attempts", 0)
        if isinstance(attempts, bool) or not isinstance(attempts, int) or attempts < 0:
            raise WorkflowError(f"state.tasks.{task_id}.attempts must be a non-negative integer")
        evidence = data.get("evidence", [])
        if not isinstance(evidence, list) or any(not isinstance(item, str) for item in evidence):
            raise WorkflowError(f"state.tasks.{task_id}.evidence must be an array of strings")
        if len(evidence) > _MAX_EVIDENCE_ITEMS or any(
            len(item) > _MAX_EVIDENCE_LENGTH for item in evidence
        ):
            raise WorkflowError(f"state.tasks.{task_id}.evidence exceeds its size limits")
        for name in ("assignedWorker", "startedAt", "completedAt", "lastError", "blockKind"):
            value = data.get(name)
            if value is not None and not isinstance(value, str):
                raise WorkflowError(f"state.tasks.{task_id}.{name} must be a string or null")
        if data.get("assignedWorker") and len(data["assignedWorker"]) > _MAX_WORKER_LENGTH:
            raise WorkflowError(f"state.tasks.{task_id}.assignedWorker is too long")
        if data.get("lastError") and len(data["lastError"]) > _MAX_ERROR_LENGTH:
            raise WorkflowError(f"state.tasks.{task_id}.lastError is too long")
        return cls(
            status=status,
            attempts=attempts,
            assigned_worker=data.get("assignedWorker"),
            started_at=data.get("startedAt"),
            completed_at=data.get("completedAt"),
            last_error=data.get("lastError"),
            block_kind=data.get("blockKind"),
            evidence=list(evidence),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "status": self.status.value,
            "attempts": self.attempts,
            "assignedWorker": self.assigned_worker,
            "startedAt": self.started_at,
            "completedAt": self.completed_at,
            "lastError": self.last_error,
            "blockKind": self.block_kind,
            "evidence": list(self.evidence),
        }


@dataclass
class ExecutionState:
    workflow_id: str
    graph_digest: str
    tasks: dict[str, TaskRun]
    revision: int = 0
    tokens_consumed: int = 0
    team_size_target: int = 0
    created_at: str = field(default_factory=utc_now)
    updated_at: str = field(default_factory=utc_now)
    schema_version: int = 1

    @classmethod
    def new(cls, graph: TaskGraph) -> ExecutionState:
        state = cls(
            workflow_id=graph.workflow_id,
            graph_digest=graph.digest,
            tasks={task.id: TaskRun() for task in graph.tasks},
        )
        state.refresh(graph)
        return state

    @classmethod
    def from_dict(cls, data: Any, graph: TaskGraph) -> ExecutionState:
        if not isinstance(data, dict):
            raise WorkflowError("execution state must be a JSON object")
        if data.get("schemaVersion") != 1:
            raise WorkflowError("execution state schemaVersion must be 1")
        if data.get("workflowId") != graph.workflow_id:
            raise WorkflowError("execution state workflowId does not match the task graph")
        if data.get("graphDigest") != graph.digest:
            raise WorkflowError(
                "execution state was created for a different task graph; migrate or reinitialize it"
            )
        revision = data.get("revision", 0)
        tokens = data.get("tokensConsumed", 0)
        team_size_target = data.get("teamSizeTarget", 0)
        if isinstance(revision, bool) or not isinstance(revision, int) or revision < 0:
            raise WorkflowError("execution state revision must be a non-negative integer")
        if isinstance(tokens, bool) or not isinstance(tokens, int) or tokens < 0:
            raise WorkflowError("execution state tokensConsumed must be a non-negative integer")
        if (
            isinstance(team_size_target, bool)
            or not isinstance(team_size_target, int)
            or not 0 <= team_size_target <= 16
        ):
            raise WorkflowError(
                "execution state teamSizeTarget must be an integer from 0 through 16"
            )
        raw_tasks = data.get("tasks")
        if not isinstance(raw_tasks, dict):
            raise WorkflowError("execution state tasks must be an object")
        expected = set(graph.task_map)
        actual = set(raw_tasks)
        if actual != expected:
            missing = sorted(expected - actual)
            extra = sorted(actual - expected)
            raise WorkflowError(
                f"execution state task set differs; missing={missing}, extra={extra}"
            )
        created_at = data.get("createdAt")
        updated_at = data.get("updatedAt")
        if not isinstance(created_at, str) or not isinstance(updated_at, str):
            raise WorkflowError("execution state timestamps must be strings")
        state = cls(
            workflow_id=graph.workflow_id,
            graph_digest=graph.digest,
            tasks={task_id: TaskRun.from_dict(raw_tasks[task_id], task_id) for task_id in actual},
            revision=revision,
            tokens_consumed=tokens,
            team_size_target=team_size_target,
            created_at=created_at,
            updated_at=updated_at,
        )
        state.refresh(graph, touch=False)
        return state

    def to_dict(self) -> dict[str, Any]:
        return {
            "schemaVersion": self.schema_version,
            "workflowId": self.workflow_id,
            "graphDigest": self.graph_digest,
            "revision": self.revision,
            "tokensConsumed": self.tokens_consumed,
            "teamSizeTarget": self.team_size_target,
            "createdAt": self.created_at,
            "updatedAt": self.updated_at,
            "status": self.overall_status,
            "tasks": {task_id: run.to_dict() for task_id, run in sorted(self.tasks.items())},
        }

    @property
    def overall_status(self) -> str:
        statuses = {run.status for run in self.tasks.values()}
        if statuses == {TaskStatus.DONE}:
            return "DONE"
        if TaskStatus.FAILED in statuses:
            return "FAILED"
        if TaskStatus.RUNNING in statuses:
            return "RUNNING"
        if TaskStatus.RESERVED in statuses:
            return "RESERVED"
        if TaskStatus.READY in statuses:
            return "READY"
        if TaskStatus.BLOCKED in statuses:
            return "BLOCKED"
        return "PENDING"

    def refresh(self, graph: TaskGraph, *, touch: bool = True) -> bool:
        """Derive readiness and dependency blocks until the state converges."""

        changed = False
        task_map = graph.task_map
        while True:
            pass_changed = False
            for task_id, task in task_map.items():
                run = self.tasks[task_id]
                if run.status in {
                    TaskStatus.RESERVED,
                    TaskStatus.RUNNING,
                    TaskStatus.DONE,
                    TaskStatus.FAILED,
                }:
                    continue
                dependency_states = [self.tasks[dep].status for dep in task.depends_on]
                blocked_dependencies = [
                    dep
                    for dep in task.depends_on
                    if self.tasks[dep].status in {TaskStatus.BLOCKED, TaskStatus.FAILED}
                ]
                if blocked_dependencies:
                    desired = TaskStatus.BLOCKED
                    reason = "blocked by dependency: " + ", ".join(blocked_dependencies)
                    if (
                        run.status != desired
                        or run.block_kind != "dependency"
                        or run.last_error != reason
                    ):
                        run.status = desired
                        run.block_kind = "dependency"
                        run.last_error = reason
                        run.assigned_worker = None
                        pass_changed = True
                    continue
                if run.status == TaskStatus.BLOCKED and run.block_kind != "dependency":
                    continue
                desired = (
                    TaskStatus.READY
                    if all(status == TaskStatus.DONE for status in dependency_states)
                    else TaskStatus.PENDING
                )
                was_dependency_block = run.block_kind == "dependency"
                if run.status != desired or was_dependency_block:
                    run.status = desired
                    run.block_kind = None
                    if was_dependency_block:
                        run.last_error = None
                    pass_changed = True
            changed = changed or pass_changed
            if not pass_changed:
                break
        if changed and touch:
            self.updated_at = utc_now()
        return changed

    def transition(
        self,
        graph: TaskGraph,
        task_id: str,
        action: str,
        *,
        worker: str | None = None,
        evidence: str | None = None,
        error: str | None = None,
        tokens: int = 0,
    ) -> None:
        if task_id not in self.tasks:
            raise WorkflowError(f"unknown task: {task_id}")
        if isinstance(tokens, bool) or not isinstance(tokens, int) or tokens < 0:
            raise WorkflowError("tokens must be a non-negative integer")
        run = self.tasks[task_id]
        now = utc_now()
        if action == "start":
            if run.status not in {TaskStatus.READY, TaskStatus.RESERVED}:
                raise WorkflowError(
                    f"{task_id} must be READY or RESERVED before start; got {run.status.value}"
                )
            if run.status == TaskStatus.RESERVED:
                if worker and worker.strip() != run.assigned_worker:
                    raise WorkflowError(
                        f"{task_id} is reserved for {run.assigned_worker!r}, not {worker.strip()!r}"
                    )
                worker = run.assigned_worker
            if not worker or not worker.strip():
                raise WorkflowError("start requires a non-empty worker")
            worker = worker.strip()
            if len(worker) > _MAX_WORKER_LENGTH:
                raise WorkflowError(
                    f"worker cannot exceed {_MAX_WORKER_LENGTH} characters"
                )
            other_assignment = next(
                (
                    other_id
                    for other_id, other in self.tasks.items()
                    if other_id != task_id
                    and other.status in {TaskStatus.RESERVED, TaskStatus.RUNNING}
                    and other.assigned_worker == worker
                ),
                None,
            )
            if other_assignment:
                raise WorkflowError(
                    f"worker {worker!r} is already assigned to {other_assignment}"
                )
            run.status = TaskStatus.RUNNING
            run.attempts += 1
            run.assigned_worker = worker
            run.started_at = now
            run.completed_at = None
            run.last_error = None
            run.block_kind = None
        elif action == "complete":
            if run.status != TaskStatus.RUNNING:
                raise WorkflowError(
                    f"{task_id} must be RUNNING before complete; got {run.status.value}"
                )
            if not evidence or not evidence.strip():
                raise WorkflowError("complete requires non-empty evidence")
            if len(evidence.strip()) > _MAX_EVIDENCE_LENGTH:
                raise WorkflowError(
                    f"evidence cannot exceed {_MAX_EVIDENCE_LENGTH} characters"
                )
            if len(run.evidence) >= _MAX_EVIDENCE_ITEMS:
                raise WorkflowError(
                    f"{task_id} cannot record more than {_MAX_EVIDENCE_ITEMS} evidence items"
                )
            run.status = TaskStatus.DONE
            run.completed_at = now
            run.last_error = None
            run.block_kind = None
            run.evidence.append(evidence.strip())
            self.tokens_consumed += tokens
        elif action == "fail":
            if run.status != TaskStatus.RUNNING:
                raise WorkflowError(
                    f"{task_id} must be RUNNING before fail; got {run.status.value}"
                )
            if not error or not error.strip():
                raise WorkflowError("fail requires a non-empty error")
            if len(error.strip()) > _MAX_ERROR_LENGTH:
                raise WorkflowError(f"error cannot exceed {_MAX_ERROR_LENGTH} characters")
            retry_limit = graph.task_map[task_id].effective_retry_limit(graph.policy)
            run.status = TaskStatus.READY if run.attempts <= retry_limit else TaskStatus.FAILED
            run.completed_at = now if run.status == TaskStatus.FAILED else None
            run.last_error = error.strip()
            run.block_kind = None
            run.assigned_worker = None
            self.tokens_consumed += tokens
        elif action == "block":
            if run.status not in {
                TaskStatus.PENDING,
                TaskStatus.READY,
                TaskStatus.RESERVED,
                TaskStatus.RUNNING,
            }:
                raise WorkflowError(f"{task_id} cannot be blocked from {run.status.value}")
            if not error or not error.strip():
                raise WorkflowError("block requires a non-empty error")
            if len(error.strip()) > _MAX_ERROR_LENGTH:
                raise WorkflowError(f"error cannot exceed {_MAX_ERROR_LENGTH} characters")
            run.status = TaskStatus.BLOCKED
            run.last_error = error.strip()
            run.block_kind = "manual"
            run.assigned_worker = None
        elif action == "unblock":
            if run.status != TaskStatus.BLOCKED or run.block_kind != "manual":
                raise WorkflowError(f"{task_id} is not manually BLOCKED")
            run.status = TaskStatus.PENDING
            run.last_error = None
            run.block_kind = None
        elif action == "release":
            if run.status != TaskStatus.RESERVED:
                raise WorkflowError(f"{task_id} is not RESERVED")
            run.status = TaskStatus.READY
            run.assigned_worker = None
            run.last_error = error.strip() if error and error.strip() else None
            run.block_kind = None
        else:
            raise WorkflowError(f"unsupported transition action: {action}")
        self.revision += 1
        self.updated_at = now
        self.refresh(graph)

    def reserve_wave(
        self, reservations: list[tuple[str, str]], desired_workers: int
    ) -> None:
        if not 0 <= desired_workers <= 16:
            raise WorkflowError("desired worker count must be from 0 through 16")
        seen: set[str] = set()
        workers: set[str] = set()
        active_workers = {
            run.assigned_worker
            for run in self.tasks.values()
            if run.status in {TaskStatus.RESERVED, TaskStatus.RUNNING}
            and run.assigned_worker
        }
        for task_id, worker in reservations:
            if task_id in seen:
                raise WorkflowError(f"duplicate wave reservation: {task_id}")
            seen.add(task_id)
            if task_id not in self.tasks:
                raise WorkflowError(f"unknown task reservation: {task_id}")
            if self.tasks[task_id].status != TaskStatus.READY:
                raise WorkflowError(
                    f"{task_id} must be READY before reservation; "
                    f"got {self.tasks[task_id].status.value}"
                )
            if not worker.strip():
                raise WorkflowError(f"{task_id} reservation requires a worker")
            clean_worker = worker.strip()
            if len(clean_worker) > _MAX_WORKER_LENGTH:
                raise WorkflowError(
                    f"worker cannot exceed {_MAX_WORKER_LENGTH} characters"
                )
            if clean_worker in workers or clean_worker in active_workers:
                raise WorkflowError(f"worker {clean_worker!r} already has active work")
            workers.add(clean_worker)
        changed = self.team_size_target != desired_workers or bool(reservations)
        for task_id, worker in reservations:
            run = self.tasks[task_id]
            run.status = TaskStatus.RESERVED
            run.assigned_worker = worker.strip()
            run.last_error = None
            run.block_kind = None
        if changed:
            self.team_size_target = desired_workers
            self.revision += 1
            self.updated_at = utc_now()


class StateStore:
    """Atomic JSON persistence with optional optimistic revision checks."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)
        self.events_path = self.path.with_name(self.path.name + ".events.jsonl")

    def append_event(self, event: dict[str, Any]) -> None:
        """Append an fsync-backed, bounded audit event beside the state file."""

        if not isinstance(event, dict):
            raise WorkflowError("execution event must be an object")
        payload = json.dumps(event, ensure_ascii=False, separators=(",", ":"))
        if len(payload.encode("utf-8")) > _MAX_EVENT_BYTES:
            raise WorkflowError("execution event exceeds its size limit")
        self.events_path.parent.mkdir(parents=True, exist_ok=True)
        lock_path = self.events_path.with_name(self.events_path.name + ".lock")
        with _exclusive_file_lock(lock_path):
            with self.events_path.open("a", encoding="utf-8", newline="\n") as handle:
                handle.write(payload + "\n")
                handle.flush()
                os.fsync(handle.fileno())

    def load(self, graph: TaskGraph) -> ExecutionState:
        try:
            if self.path.stat().st_size > _MAX_STATE_BYTES:
                raise WorkflowError(
                    f"execution state exceeds the {_MAX_STATE_BYTES}-byte input limit"
                )
            with self.path.open(encoding="utf-8") as handle:
                return ExecutionState.from_dict(json.load(handle), graph)
        except FileNotFoundError as exc:
            raise WorkflowError(f"execution state does not exist: {self.path}") from exc
        except json.JSONDecodeError as exc:
            raise WorkflowError(f"invalid execution state JSON: {exc}") from exc

    def save(self, state: ExecutionState, *, expected_revision: int | None = None) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        lock_path = self.path.with_name(self.path.name + ".lock")
        with _exclusive_file_lock(lock_path):
            if expected_revision is not None and self.path.exists():
                try:
                    current = json.loads(self.path.read_text(encoding="utf-8"))
                except (OSError, json.JSONDecodeError) as exc:
                    raise StateConflictError(
                        f"cannot verify current state revision: {exc}"
                    ) from exc
                if current.get("revision") != expected_revision:
                    raise StateConflictError(
                        f"state revision conflict: expected {expected_revision}, "
                        f"found {current.get('revision')!r}"
                    )
            payload = json.dumps(state.to_dict(), ensure_ascii=False, indent=2) + "\n"
            descriptor, temporary_name = tempfile.mkstemp(
                prefix=self.path.name + ".", suffix=".tmp", dir=self.path.parent
            )
            try:
                with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as handle:
                    handle.write(payload)
                    handle.flush()
                    os.fsync(handle.fileno())
                os.replace(temporary_name, self.path)
            except BaseException:
                try:
                    os.unlink(temporary_name)
                except FileNotFoundError:
                    pass
                raise
