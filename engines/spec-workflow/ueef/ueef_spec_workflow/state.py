"""Durable execution state and guarded task transitions."""

from __future__ import annotations

import json
import os
import re
import secrets
import tempfile
import time
import uuid
from contextlib import contextmanager
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from enum import StrEnum
from pathlib import Path
from typing import Any

from .errors import StateConflictError, WorkflowError
from .model import TaskGraph, scopes_overlap

_MAX_STATE_BYTES = 10 * 1024 * 1024
_MAX_EVIDENCE_ITEMS = 100
_MAX_EVIDENCE_LENGTH = 4000
_MAX_ERROR_LENGTH = 4000
_MAX_WORKER_LENGTH = 128
_MAX_HOST_HANDLE_LENGTH = 1024
_MAX_EVENT_BYTES = 64 * 1024
_DEFAULT_LEASE_SECONDS = 300
_MAX_LEASE_SECONDS = 3600
_MAX_LEASE_RENEWALS = 3


def utc_now() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def _utc_text(value: datetime) -> str:
    if value.tzinfo is None:
        raise WorkflowError("lease timestamps must be timezone-aware")
    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


def _parse_utc(value: str) -> datetime:
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(UTC)
    except ValueError as exc:
        raise WorkflowError(f"invalid UTC timestamp: {value!r}") from exc


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
    attempt_id: str | None = None
    lease_generation: int = 0
    fencing_token: str | None = None
    lease_expires_at: str | None = None
    heartbeat_at: str | None = None
    lease_renewals: int = 0
    host_handle: str | None = None

    @classmethod
    def from_dict(cls, data: Any, task_id: str, *, enforce_fence: bool = True) -> TaskRun:
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
        for name in (
            "assignedWorker",
            "startedAt",
            "completedAt",
            "lastError",
            "blockKind",
            "attemptId",
            "fencingToken",
            "leaseExpiresAt",
            "heartbeatAt",
            "hostHandle",
        ):
            value = data.get(name)
            if value is not None and not isinstance(value, str):
                raise WorkflowError(f"state.tasks.{task_id}.{name} must be a string or null")
        if data.get("assignedWorker") and len(data["assignedWorker"]) > _MAX_WORKER_LENGTH:
            raise WorkflowError(f"state.tasks.{task_id}.assignedWorker is too long")
        if data.get("lastError") and len(data["lastError"]) > _MAX_ERROR_LENGTH:
            raise WorkflowError(f"state.tasks.{task_id}.lastError is too long")
        if data.get("hostHandle") and len(data["hostHandle"]) > _MAX_HOST_HANDLE_LENGTH:
            raise WorkflowError(f"state.tasks.{task_id}.hostHandle is too long")
        lease_generation = data.get("leaseGeneration", 0)
        lease_renewals = data.get("leaseRenewals", 0)
        if (
            isinstance(lease_generation, bool)
            or not isinstance(lease_generation, int)
            or lease_generation < 0
        ):
            raise WorkflowError(
                f"state.tasks.{task_id}.leaseGeneration must be a non-negative integer"
            )
        if (
            isinstance(lease_renewals, bool)
            or not isinstance(lease_renewals, int)
            or lease_renewals < 0
        ):
            raise WorkflowError(
                f"state.tasks.{task_id}.leaseRenewals must be a non-negative integer"
            )
        active = status in {TaskStatus.RESERVED, TaskStatus.RUNNING}
        if active and enforce_fence:
            if not data.get("assignedWorker") or not data.get("attemptId"):
                raise WorkflowError(f"state.tasks.{task_id} active lease identity is incomplete")
            try:
                uuid.UUID(data["attemptId"])
            except (ValueError, AttributeError) as exc:
                raise WorkflowError(f"state.tasks.{task_id}.attemptId must be a UUID") from exc
            if not re.fullmatch(r"[0-9a-f]{64}", data.get("fencingToken") or ""):
                raise WorkflowError(
                    f"state.tasks.{task_id}.fencingToken must be a 256-bit lowercase hex token"
                )
            if lease_generation < 1 or lease_generation > attempts:
                raise WorkflowError(
                    f"state.tasks.{task_id}.leaseGeneration must identify a current attempt"
                )
            if not data.get("leaseExpiresAt") or not data.get("heartbeatAt"):
                raise WorkflowError(f"state.tasks.{task_id} active lease timestamps are incomplete")
            _parse_utc(data["leaseExpiresAt"])
            _parse_utc(data["heartbeatAt"])
        if enforce_fence:
            cls._validate_status_fields(data, task_id, status)
        return cls(
            status=status,
            attempts=attempts,
            assigned_worker=data.get("assignedWorker"),
            started_at=data.get("startedAt"),
            completed_at=data.get("completedAt"),
            last_error=data.get("lastError"),
            block_kind=data.get("blockKind"),
            evidence=list(evidence),
            attempt_id=data.get("attemptId"),
            lease_generation=lease_generation,
            fencing_token=data.get("fencingToken"),
            lease_expires_at=data.get("leaseExpiresAt"),
            heartbeat_at=data.get("heartbeatAt"),
            lease_renewals=lease_renewals,
            host_handle=data.get("hostHandle"),
        )

    @staticmethod
    def _validate_status_fields(data: dict[str, Any], task_id: str, status: TaskStatus) -> None:
        assigned = data.get("assignedWorker")
        started = data.get("startedAt")
        completed = data.get("completedAt")
        error = data.get("lastError")
        block_kind = data.get("blockKind")
        evidence = data.get("evidence", [])
        active_identity = any(
            data.get(name) is not None
            for name in ("fencingToken", "leaseExpiresAt", "heartbeatAt", "hostHandle")
        )
        if status == TaskStatus.RESERVED:
            if started or completed or error or block_kind:
                raise WorkflowError(f"state.tasks.{task_id} RESERVED fields are inconsistent")
        elif status == TaskStatus.RUNNING:
            if not started or completed or error or block_kind:
                raise WorkflowError(f"state.tasks.{task_id} RUNNING fields are inconsistent")
            _parse_utc(started)
        elif status == TaskStatus.BLOCKED:
            if block_kind not in {"manual", "dependency"} or not error:
                raise WorkflowError(f"state.tasks.{task_id} BLOCKED requires a kind and error")
            if assigned or started or completed or active_identity:
                raise WorkflowError(f"state.tasks.{task_id} BLOCKED fields are inconsistent")
        elif status == TaskStatus.DONE:
            if not completed or not evidence:
                raise WorkflowError(f"state.tasks.{task_id} DONE requires evidence and completedAt")
            _parse_utc(completed)
            if assigned or error or block_kind or active_identity:
                raise WorkflowError(f"state.tasks.{task_id} DONE fields are inconsistent")
        elif status == TaskStatus.FAILED:
            if not completed or not error:
                raise WorkflowError(f"state.tasks.{task_id} FAILED requires error and completedAt")
            _parse_utc(completed)
            if assigned or block_kind or active_identity:
                raise WorkflowError(f"state.tasks.{task_id} FAILED fields are inconsistent")
        elif assigned or completed or block_kind or active_identity:
            raise WorkflowError(f"state.tasks.{task_id} {status.value} fields are inconsistent")

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
            "attemptId": self.attempt_id,
            "leaseGeneration": self.lease_generation,
            "fencingToken": self.fencing_token,
            "leaseExpiresAt": self.lease_expires_at,
            "heartbeatAt": self.heartbeat_at,
            "leaseRenewals": self.lease_renewals,
            "hostHandle": self.host_handle,
        }


@dataclass
class ExecutionState:
    workflow_id: str
    graph_digest: str
    tasks: dict[str, TaskRun]
    revision: int = 0
    tokens_consumed: int = 0
    token_ledger: dict[str, int] = field(default_factory=dict)
    team_size_target: int = 0
    paused: bool = False
    pause_reason: str | None = None
    paused_at: str | None = None
    created_at: str = field(default_factory=utc_now)
    updated_at: str = field(default_factory=utc_now)
    execution_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    verification_status: str = "NOT_REQUIRED"
    verification_evidence: str | None = None
    verification_diff_digest: str | None = None
    verification_invalidated_tasks: list[str] = field(default_factory=list)
    verification_rounds: int = 0
    convergence_history: list[str] = field(default_factory=list)
    schema_version: int = 2

    @classmethod
    def new(cls, graph: TaskGraph) -> ExecutionState:
        state = cls(
            workflow_id=graph.workflow_id,
            graph_digest=graph.digest,
            tasks={task.id: TaskRun() for task in graph.tasks},
            verification_status="PENDING" if graph.schema_version == 2 else "NOT_REQUIRED",
        )
        state.refresh(graph)
        return state

    @classmethod
    def from_dict(cls, data: Any, graph: TaskGraph) -> ExecutionState:
        if not isinstance(data, dict):
            raise WorkflowError("execution state must be a JSON object")
        if data.get("schemaVersion") not in {1, 2}:
            raise WorkflowError("execution state schemaVersion must be 1 or 2")
        if data.get("workflowId") != graph.workflow_id:
            raise WorkflowError("execution state workflowId does not match the task graph")
        if data.get("graphDigest") != graph.digest:
            raise WorkflowError(
                "execution state was created for a different task graph; migrate or reinitialize it"
            )
        revision = data.get("revision", 0)
        tokens = data.get("tokensConsumed", 0)
        token_ledger = data.get("tokenLedger")
        if token_ledger is None:
            token_ledger = {"legacy-unattributed": tokens} if tokens else {}
        team_size_target = data.get("teamSizeTarget", 0)
        paused = data.get("paused", False)
        pause_reason = data.get("pauseReason")
        paused_at = data.get("pausedAt")
        if isinstance(revision, bool) or not isinstance(revision, int) or revision < 0:
            raise WorkflowError("execution state revision must be a non-negative integer")
        if isinstance(tokens, bool) or not isinstance(tokens, int) or tokens < 0:
            raise WorkflowError("execution state tokensConsumed must be a non-negative integer")
        if (
            not isinstance(token_ledger, dict)
            or any(not isinstance(key, str) or not key for key in token_ledger)
            or any(
                isinstance(value, bool) or not isinstance(value, int) or value < 0
                for value in token_ledger.values()
            )
            or sum(token_ledger.values()) != tokens
        ):
            raise WorkflowError("execution state tokenLedger must exactly reconcile tokensConsumed")
        if (
            isinstance(team_size_target, bool)
            or not isinstance(team_size_target, int)
            or not 0 <= team_size_target <= 16
        ):
            raise WorkflowError(
                "execution state teamSizeTarget must be an integer from 0 through 16"
            )
        if not isinstance(paused, bool):
            raise WorkflowError("execution state paused must be boolean")
        if pause_reason is not None and (
            not isinstance(pause_reason, str) or not pause_reason.strip() or len(pause_reason) > 512
        ):
            raise WorkflowError("execution state pauseReason must be a bounded non-empty string")
        if not paused and pause_reason is not None:
            raise WorkflowError("execution state pauseReason requires paused=true")
        if paused_at is not None:
            if not isinstance(paused_at, str):
                raise WorkflowError("execution state pausedAt must be a UTC timestamp or null")
            _parse_utc(paused_at)
        if paused != (paused_at is not None):
            raise WorkflowError("execution state pausedAt must be present exactly while paused")
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
        _parse_utc(created_at)
        _parse_utc(updated_at)
        execution_id_value = data.get("executionId")
        if data["schemaVersion"] == 2:
            try:
                uuid.UUID(execution_id_value)
            except (ValueError, AttributeError, TypeError) as exc:
                raise WorkflowError("execution state executionId must be a UUID") from exc
            execution_id = str(execution_id_value)
        else:
            execution_id = (
                execution_id_value if isinstance(execution_id_value, str) else str(uuid.uuid4())
            )
        verification_status = data.get(
            "verificationStatus",
            "PENDING" if graph.schema_version == 2 else "NOT_REQUIRED",
        )
        if verification_status not in {"PENDING", "PASS", "FAIL", "NOT_REQUIRED"}:
            raise WorkflowError("execution state verificationStatus is invalid")
        verification_evidence = data.get("verificationEvidence")
        if verification_evidence is not None and (
            not isinstance(verification_evidence, str)
            or len(verification_evidence) > _MAX_EVIDENCE_LENGTH
        ):
            raise WorkflowError("execution state verificationEvidence is invalid")
        verification_diff_digest = data.get("verificationDiffDigest")
        if verification_diff_digest is not None and not re.fullmatch(
            r"[0-9a-f]{64}", verification_diff_digest
        ):
            raise WorkflowError("execution state verificationDiffDigest must be a SHA-256 digest")
        invalidated_tasks = data.get("verificationInvalidatedTasks", [])
        if (
            not isinstance(invalidated_tasks, list)
            or any(not isinstance(item, str) for item in invalidated_tasks)
            or not set(invalidated_tasks).issubset(expected)
            or len(invalidated_tasks) != len(set(invalidated_tasks))
        ):
            raise WorkflowError("execution state verificationInvalidatedTasks is invalid")
        verification_rounds = data.get("verificationRounds", 0)
        if (
            isinstance(verification_rounds, bool)
            or not isinstance(verification_rounds, int)
            or verification_rounds < 0
        ):
            raise WorkflowError("execution state verificationRounds must be a non-negative integer")
        convergence_history = data.get("convergenceHistory", [])
        if (
            not isinstance(convergence_history, list)
            or len(convergence_history) > 3
            or any(
                not isinstance(item, str) or not re.fullmatch(r"[0-9a-f]{64}", item)
                for item in convergence_history
            )
            or len(convergence_history) != len(set(convergence_history))
        ):
            raise WorkflowError("execution state convergenceHistory is invalid")
        state = cls(
            workflow_id=graph.workflow_id,
            graph_digest=graph.digest,
            tasks={
                task_id: TaskRun.from_dict(
                    raw_tasks[task_id], task_id, enforce_fence=data["schemaVersion"] == 2
                )
                for task_id in actual
            },
            revision=revision,
            tokens_consumed=tokens,
            token_ledger=dict(token_ledger),
            team_size_target=team_size_target,
            paused=paused,
            pause_reason=pause_reason,
            paused_at=paused_at,
            created_at=created_at,
            updated_at=updated_at,
            execution_id=execution_id,
            schema_version=2,
            verification_status=verification_status,
            verification_evidence=verification_evidence,
            verification_diff_digest=verification_diff_digest,
            verification_invalidated_tasks=list(invalidated_tasks),
            verification_rounds=verification_rounds,
            convergence_history=list(convergence_history),
        )
        state.refresh(graph, touch=False)
        return state

    def to_dict(self) -> dict[str, Any]:
        return {
            "schemaVersion": self.schema_version,
            "workflowId": self.workflow_id,
            "graphDigest": self.graph_digest,
            "executionId": self.execution_id,
            "verificationStatus": self.verification_status,
            "verificationEvidence": self.verification_evidence,
            "verificationDiffDigest": self.verification_diff_digest,
            "verificationInvalidatedTasks": list(self.verification_invalidated_tasks),
            "verificationRounds": self.verification_rounds,
            "convergenceHistory": list(self.convergence_history),
            "revision": self.revision,
            "tokensConsumed": self.tokens_consumed,
            "tokenLedger": dict(sorted(self.token_ledger.items())),
            "teamSizeTarget": self.team_size_target,
            "paused": self.paused,
            "pauseReason": self.pause_reason,
            "pausedAt": self.paused_at,
            "createdAt": self.created_at,
            "updatedAt": self.updated_at,
            "status": self.overall_status,
            "tasks": {task_id: run.to_dict() for task_id, run in sorted(self.tasks.items())},
        }

    @property
    def overall_status(self) -> str:
        if self.paused:
            return "PAUSED"
        statuses = {run.status for run in self.tasks.values()}
        if statuses == {TaskStatus.DONE}:
            if self.verification_status in {"NOT_REQUIRED", "PASS"}:
                return "DONE"
            if self.verification_status == "FAIL":
                return "NEEDS_REPLAN"
            return "VERIFYING"
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

    def pause(self, reason: str, *, now: datetime | None = None) -> None:
        normalized = reason.strip()
        if not normalized or len(normalized) > 512:
            raise WorkflowError("pause requires a bounded non-empty reason")
        if self.paused:
            if self.pause_reason != normalized:
                raise WorkflowError("workflow is already paused for a different reason")
            return
        self.paused = True
        self.pause_reason = normalized
        self.paused_at = _utc_text(now or datetime.now(UTC))
        self.revision += 1
        self.updated_at = self.paused_at

    def resume(self, *, now: datetime | None = None) -> None:
        if not self.paused:
            return
        current = now or datetime.now(UTC)
        if not self.paused_at:
            raise WorkflowError("paused workflow is missing pausedAt")
        paused_for = current - _parse_utc(self.paused_at)
        if paused_for.total_seconds() < 0:
            raise WorkflowError("resume time cannot precede pause time")
        for run in self.tasks.values():
            if run.status not in {TaskStatus.RESERVED, TaskStatus.RUNNING}:
                continue
            if run.lease_expires_at:
                run.lease_expires_at = _utc_text(_parse_utc(run.lease_expires_at) + paused_for)
            if run.heartbeat_at:
                run.heartbeat_at = _utc_text(_parse_utc(run.heartbeat_at) + paused_for)
        self.paused = False
        self.pause_reason = None
        self.paused_at = None
        self.revision += 1
        self.updated_at = _utc_text(current)

    def steal_unstarted_reservation(
        self, graph: TaskGraph, task_id: str, *, from_worker: str, to_worker: str
    ) -> None:
        run = self.tasks.get(task_id)
        if run is None:
            raise WorkflowError(f"unknown task: {task_id}")
        if run.status != TaskStatus.RESERVED or run.host_handle:
            raise WorkflowError("only an undispatched RESERVED task can be reassigned")
        if run.assigned_worker != from_worker:
            raise WorkflowError("reservation worker identity mismatch")
        if not to_worker.strip() or to_worker.casefold() == from_worker.casefold():
            raise WorkflowError("replacement worker must be different and non-empty")
        run.status = TaskStatus.READY
        run.assigned_worker = None
        run.attempt_id = None
        run.fencing_token = None
        run.lease_expires_at = None
        run.heartbeat_at = None
        run.lease_renewals = 0
        self.reserve_wave([(task_id, to_worker)], self.team_size_target)

    def invalidate_verification(
        self, graph: TaskGraph, changed_paths: list[str]
    ) -> tuple[str, ...]:
        affected = sorted(
            task.id
            for task in graph.tasks
            if task.write_set and scopes_overlap(task.write_set, changed_paths)
        )
        if not affected:
            return ()
        self.verification_status = "PENDING"
        self.verification_evidence = None
        self.verification_diff_digest = None
        self.verification_invalidated_tasks = affected
        self.revision += 1
        self.updated_at = utc_now()
        return tuple(affected)

    def record_verification(
        self, *, passed: bool, evidence: str, diff_digest: str, independent: bool
    ) -> None:
        if not independent:
            raise WorkflowError("completion verification must be independent")
        if not evidence.strip():
            raise WorkflowError("verification requires non-empty evidence")
        if not re.fullmatch(r"[0-9a-f]{64}", diff_digest):
            raise WorkflowError("verification diff_digest must be a SHA-256 digest")
        self.verification_status = "PASS" if passed else "FAIL"
        self.verification_evidence = evidence.strip()
        self.verification_diff_digest = diff_digest
        self.verification_invalidated_tasks = []
        self.verification_rounds += 1
        self.revision += 1
        self.updated_at = utc_now()

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
                if run.status == TaskStatus.BLOCKED and run.block_kind != "dependency":
                    continue
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
        tokens: int | None = None,
    ) -> None:
        if task_id not in self.tasks:
            raise WorkflowError(f"unknown task: {task_id}")
        if tokens is not None and (
            isinstance(tokens, bool) or not isinstance(tokens, int) or tokens < 0
        ):
            raise WorkflowError("tokens must be a non-negative integer or null")
        run = self.tasks[task_id]
        now = utc_now()
        if action == "start":
            if run.status != TaskStatus.RESERVED:
                raise WorkflowError(
                    f"{task_id} must be RESERVED before start; got {run.status.value}"
                )
            self.assert_live_lease(task_id)
            if worker and worker.strip() != run.assigned_worker:
                raise WorkflowError(
                    f"{task_id} is reserved for {run.assigned_worker!r}, not {worker.strip()!r}"
                )
            worker = run.assigned_worker
            if not worker or not worker.strip():
                raise WorkflowError("start requires a non-empty worker")
            worker = worker.strip()
            if len(worker) > _MAX_WORKER_LENGTH:
                raise WorkflowError(f"worker cannot exceed {_MAX_WORKER_LENGTH} characters")
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
                raise WorkflowError(f"worker {worker!r} is already assigned to {other_assignment}")
            run.status = TaskStatus.RUNNING
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
            self.assert_live_lease(task_id)
            if not evidence or not evidence.strip():
                raise WorkflowError("complete requires non-empty evidence")
            if len(evidence.strip()) > _MAX_EVIDENCE_LENGTH:
                raise WorkflowError(f"evidence cannot exceed {_MAX_EVIDENCE_LENGTH} characters")
            if len(run.evidence) >= _MAX_EVIDENCE_ITEMS:
                raise WorkflowError(
                    f"{task_id} cannot record more than {_MAX_EVIDENCE_ITEMS} evidence items"
                )
            charged, over_budget = self._account_attempt_tokens(graph, task_id, tokens)
            run.status = TaskStatus.FAILED if over_budget else TaskStatus.DONE
            run.completed_at = now
            run.last_error = (
                f"token budget exceeded after charging {charged} tokens" if over_budget else None
            )
            run.block_kind = None
            if not over_budget:
                run.evidence.append(evidence.strip())
            self._clear_active_lease(run)
        elif action == "fail":
            if run.status != TaskStatus.RUNNING:
                raise WorkflowError(
                    f"{task_id} must be RUNNING before fail; got {run.status.value}"
                )
            self.assert_live_lease(task_id)
            if not error or not error.strip():
                raise WorkflowError("fail requires a non-empty error")
            if len(error.strip()) > _MAX_ERROR_LENGTH:
                raise WorkflowError(f"error cannot exceed {_MAX_ERROR_LENGTH} characters")
            retry_limit = graph.task_map[task_id].effective_retry_limit(graph.policy)
            charged, over_budget = self._account_attempt_tokens(graph, task_id, tokens)
            run.status = (
                TaskStatus.FAILED
                if over_budget
                else TaskStatus.READY if run.attempts <= retry_limit else TaskStatus.FAILED
            )
            run.completed_at = now if run.status == TaskStatus.FAILED else None
            run.last_error = (
                f"token budget exceeded after charging {charged} tokens"
                if over_budget
                else error.strip()
            )
            run.block_kind = None
            run.started_at = None if run.status == TaskStatus.READY else run.started_at
            self._clear_active_lease(run)
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
            run.started_at = None
            run.completed_at = None
            self._clear_active_lease(run)
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
            run.started_at = None
            self._clear_active_lease(run)
        else:
            raise WorkflowError(f"unsupported transition action: {action}")
        self.revision += 1
        self.updated_at = now
        self.refresh(graph)

    def assert_live_lease(self, task_id: str, *, now: datetime | None = None) -> None:
        run = self.tasks.get(task_id)
        if run is None:
            raise WorkflowError(f"unknown task: {task_id}")
        if run.status not in {TaskStatus.RESERVED, TaskStatus.RUNNING}:
            raise WorkflowError(f"{task_id} has no active lease")
        current = now or datetime.now(UTC)
        if not run.lease_expires_at or current >= _parse_utc(run.lease_expires_at):
            raise WorkflowError(f"{task_id} execution lease expired")

    def _account_attempt_tokens(
        self, graph: TaskGraph, task_id: str, reported: int | None
    ) -> tuple[int, bool]:
        run = self.tasks[task_id]
        if not run.attempt_id:
            raise WorkflowError(f"{task_id} has no attempt identity for token accounting")
        charge = reported
        if charge is None or (charge == 0 and graph.policy.token_budget is not None):
            charge = graph.task_map[task_id].estimated_tokens
        existing = self.token_ledger.get(run.attempt_id)
        if existing is not None:
            if existing != charge:
                raise WorkflowError("attempt token receipt conflicts with the durable ledger")
            return existing, bool(
                graph.policy.token_budget is not None
                and self.tokens_consumed > graph.policy.token_budget
            )
        self.token_ledger[run.attempt_id] = charge
        self.tokens_consumed += charge
        return charge, bool(
            graph.policy.token_budget is not None
            and self.tokens_consumed > graph.policy.token_budget
        )

    @staticmethod
    def _clear_active_lease(run: TaskRun) -> None:
        run.assigned_worker = None
        run.fencing_token = None
        run.lease_expires_at = None
        run.heartbeat_at = None
        run.host_handle = None

    def reserve_wave(
        self,
        reservations: list[tuple[str, str]],
        desired_workers: int,
        *,
        lease_seconds: int = _DEFAULT_LEASE_SECONDS,
        now: datetime | None = None,
    ) -> None:
        if (
            isinstance(lease_seconds, bool)
            or not isinstance(lease_seconds, int)
            or not 1 <= lease_seconds <= _MAX_LEASE_SECONDS
        ):
            raise WorkflowError(f"lease_seconds must be from 1 through {_MAX_LEASE_SECONDS}")
        lease_now = now or datetime.now(UTC)
        lease_now_text = _utc_text(lease_now)
        lease_expires = _utc_text(lease_now + timedelta(seconds=lease_seconds))
        if not 0 <= desired_workers <= 16:
            raise WorkflowError("desired worker count must be from 0 through 16")
        seen: set[str] = set()
        workers: set[str] = set()
        active_workers = {
            run.assigned_worker
            for run in self.tasks.values()
            if run.status in {TaskStatus.RESERVED, TaskStatus.RUNNING} and run.assigned_worker
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
                raise WorkflowError(f"worker cannot exceed {_MAX_WORKER_LENGTH} characters")
            if clean_worker in workers or clean_worker in active_workers:
                raise WorkflowError(f"worker {clean_worker!r} already has active work")
            workers.add(clean_worker)
        changed = self.team_size_target != desired_workers or bool(reservations)
        for task_id, worker in reservations:
            run = self.tasks[task_id]
            run.status = TaskStatus.RESERVED
            run.assigned_worker = worker.strip()
            run.attempts += 1
            run.attempt_id = str(uuid.uuid4())
            run.lease_generation += 1
            run.fencing_token = secrets.token_hex(32)
            run.heartbeat_at = lease_now_text
            run.lease_expires_at = lease_expires
            run.lease_renewals = 0
            run.host_handle = None
            run.last_error = None
            run.block_kind = None
        if changed:
            self.team_size_target = desired_workers
            self.revision += 1
            self.updated_at = utc_now()

    def heartbeat(
        self,
        task_id: str,
        attempt_id: str,
        fencing_token: str,
        *,
        now: datetime | None = None,
        extend_seconds: int = _DEFAULT_LEASE_SECONDS,
    ) -> None:
        if task_id not in self.tasks:
            raise WorkflowError(f"unknown task: {task_id}")
        if (
            isinstance(extend_seconds, bool)
            or not isinstance(extend_seconds, int)
            or not 1 <= extend_seconds <= _MAX_LEASE_SECONDS
        ):
            raise WorkflowError(f"extend_seconds must be from 1 through {_MAX_LEASE_SECONDS}")
        run = self.tasks[task_id]
        current = now or datetime.now(UTC)
        if run.status not in {TaskStatus.RESERVED, TaskStatus.RUNNING}:
            raise WorkflowError(f"{task_id} has no active lease")
        if run.attempt_id != attempt_id or run.fencing_token != fencing_token:
            raise WorkflowError("heartbeat identity mismatch")
        if not run.lease_expires_at or current >= _parse_utc(run.lease_expires_at):
            raise WorkflowError("cannot renew an expired lease")
        if run.lease_renewals >= _MAX_LEASE_RENEWALS:
            raise WorkflowError("lease renewal limit reached")
        run.heartbeat_at = _utc_text(current)
        run.lease_expires_at = _utc_text(current + timedelta(seconds=extend_seconds))
        run.lease_renewals += 1
        self.revision += 1
        self.updated_at = run.heartbeat_at

    def reclaim_expired(self, graph: TaskGraph, *, now: datetime | None = None) -> tuple[str, ...]:
        if self.paused:
            return ()
        current = now or datetime.now(UTC)
        reclaimed: list[str] = []
        for task_id, run in self.tasks.items():
            if run.status not in {TaskStatus.RESERVED, TaskStatus.RUNNING}:
                continue
            if not run.lease_expires_at or current < _parse_utc(run.lease_expires_at):
                continue
            retry_limit = graph.task_map[task_id].effective_retry_limit(graph.policy)
            run.status = TaskStatus.READY if run.attempts <= retry_limit else TaskStatus.FAILED
            run.assigned_worker = None
            run.last_error = "execution lease expired"
            run.completed_at = _utc_text(current) if run.status == TaskStatus.FAILED else None
            run.started_at = None if run.status == TaskStatus.READY else run.started_at
            self._clear_active_lease(run)
            reclaimed.append(task_id)
        if reclaimed:
            self.revision += 1
            self.updated_at = _utc_text(current)
            self.refresh(graph, touch=False)
        return tuple(reclaimed)


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
            if expected_revision is not None and not self.path.exists():
                raise StateConflictError(
                    f"state revision conflict: expected {expected_revision}, found missing state"
                )
            if expected_revision is not None:
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
