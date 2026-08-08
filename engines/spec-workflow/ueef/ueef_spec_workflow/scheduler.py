"""Conflict-aware execution-wave scheduling with bounded dynamic team sizing."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from .model import TaskGraph, TaskSpec, scopes_overlap
from .state import ExecutionState, TaskStatus

_TIER_WORKER_CAP = {"T0": 1, "T1": 1, "T2": 2, "T3": 4, "T4": 6}
_SINGLE_WORKER_BUDGET_MODES = frozenset({"minimal"})


@dataclass(frozen=True)
class ScheduledTask:
    task_id: str
    worker: str
    estimated_tokens: int
    critical_path_weight: int

    def to_dict(self) -> dict[str, Any]:
        return {
            "taskId": self.task_id,
            "worker": self.worker,
            "estimatedTokens": self.estimated_tokens,
            "criticalPathWeight": self.critical_path_weight,
        }


@dataclass(frozen=True)
class ScheduleDecision:
    workflow_id: str
    state_revision: int
    state_status: str
    worker_cap: int
    current_workers: int
    desired_workers: int
    scale_action: str
    tasks: tuple[ScheduledTask, ...]
    deferred: tuple[dict[str, str], ...]
    budget_remaining: int | None

    def to_dict(self) -> dict[str, Any]:
        return {
            "schemaVersion": 1,
            "workflowId": self.workflow_id,
            "stateRevision": self.state_revision,
            "stateStatus": self.state_status,
            "team": {
                "workerCap": self.worker_cap,
                "currentWorkers": self.current_workers,
                "desiredWorkers": self.desired_workers,
                "scaleAction": self.scale_action,
            },
            "budgetRemaining": self.budget_remaining,
            "wave": [task.to_dict() for task in self.tasks],
            "deferred": list(self.deferred),
        }


class Scheduler:
    """Select a safe, high-value wave without launching host workers itself."""

    def __init__(self, graph: TaskGraph) -> None:
        self.graph = graph
        self._task_map = graph.task_map
        self._weights = graph.downstream_weights()

    def _budget_remaining(self, state: ExecutionState) -> int | None:
        budget = self.graph.policy.token_budget
        if budget is None:
            return None
        active_reservation = sum(
            self._task_map[task_id].estimated_tokens
            for task_id, run in state.tasks.items()
            if run.status in {TaskStatus.RESERVED, TaskStatus.RUNNING}
        )
        return max(0, budget - state.tokens_consumed - active_reservation)

    def _worker_limits(self, state: ExecutionState, ready: list[TaskSpec]) -> tuple[int, int]:
        policy = self.graph.policy
        total_cap = min(policy.max_workers, _TIER_WORKER_CAP[policy.tier])
        if policy.token_budget_mode in _SINGLE_WORKER_BUDGET_MODES:
            total_cap = min(total_cap, 1)
        remaining = self._budget_remaining(state)
        if remaining is not None and ready:
            smallest = min(task.estimated_tokens for task in ready)
            total_cap = min(total_cap, remaining // smallest)
        current_workers = len(
            {
                run.assigned_worker
                for run in state.tasks.values()
                if run.status in {TaskStatus.RESERVED, TaskStatus.RUNNING}
                and run.assigned_worker
            }
        )
        return max(0, total_cap), max(0, total_cap - current_workers)

    @staticmethod
    def _can_share_wave(task: TaskSpec, companions: list[TaskSpec]) -> tuple[bool, str]:
        if not companions:
            return True, ""
        if task.risk == 3 or any(item.risk == 3 for item in companions):
            return False, "risk-3 tasks run in an isolated wave"
        if not task.parallel_safe or any(not item.parallel_safe for item in companions):
            return False, "task is not marked parallelSafe"
        if not task.read_only and not task.write_set:
            return False, "task has an unscoped write set"
        for item in companions:
            if not item.read_only and not item.write_set:
                return False, f"{item.id} has an unscoped write set"
            if scopes_overlap(task.write_set, item.write_set):
                return False, f"write scope overlaps {item.id}"
            if scopes_overlap(task.write_set, item.forbidden_paths):
                return False, f"write scope enters {item.id} forbidden paths"
            if scopes_overlap(item.write_set, task.forbidden_paths):
                return False, f"{item.id} write scope enters this task's forbidden paths"
        return True, ""

    def decide(self, state: ExecutionState) -> ScheduleDecision:
        state.refresh(self.graph)
        ready = [
            self._task_map[task_id]
            for task_id, run in state.tasks.items()
            if run.status == TaskStatus.READY
        ]
        ready.sort(
            key=lambda task: (-task.priority, -self._weights[task.id], -task.risk, task.id)
        )
        total_cap, available_slots = self._worker_limits(state, ready)
        budget_remaining = self._budget_remaining(state)
        selected: list[TaskSpec] = []
        active = [
            self._task_map[task_id]
            for task_id, run in state.tasks.items()
            if run.status in {TaskStatus.RESERVED, TaskStatus.RUNNING}
        ]
        deferred: list[dict[str, str]] = []
        planned_tokens = 0
        for task in ready:
            if len(selected) >= available_slots:
                deferred.append({"taskId": task.id, "reason": "worker cap reached"})
                continue
            if (
                budget_remaining is not None
                and planned_tokens + task.estimated_tokens > budget_remaining
            ):
                deferred.append({"taskId": task.id, "reason": "token budget would be exceeded"})
                continue
            allowed, reason = self._can_share_wave(task, active + selected)
            if not allowed:
                deferred.append({"taskId": task.id, "reason": reason})
                continue
            selected.append(task)
            planned_tokens += task.estimated_tokens
        current_workers = len(
            {
                run.assigned_worker
                for run in state.tasks.values()
                if run.status in {TaskStatus.RESERVED, TaskStatus.RUNNING}
                and run.assigned_worker
            }
        )
        desired_workers = current_workers + len(selected)
        previous_target = state.team_size_target
        if desired_workers > previous_target:
            scale_action = "GROW"
        elif desired_workers < previous_target:
            scale_action = "SHRINK"
        else:
            scale_action = "HOLD"
        used_workers = {
            run.assigned_worker
            for run in state.tasks.values()
            if run.status in {TaskStatus.RESERVED, TaskStatus.RUNNING}
            and run.assigned_worker
        }
        next_worker = 1
        scheduled_items: list[ScheduledTask] = []
        for task in selected:
            while f"worker-{next_worker}" in used_workers:
                next_worker += 1
            worker = f"worker-{next_worker}"
            used_workers.add(worker)
            next_worker += 1
            scheduled_items.append(
                ScheduledTask(
                    task_id=task.id,
                    worker=worker,
                    estimated_tokens=task.estimated_tokens,
                    critical_path_weight=self._weights[task.id],
                )
            )
        scheduled = tuple(scheduled_items)
        return ScheduleDecision(
            workflow_id=self.graph.workflow_id,
            state_revision=state.revision,
            state_status=state.overall_status,
            worker_cap=total_cap,
            current_workers=current_workers,
            desired_workers=desired_workers,
            scale_action=scale_action,
            tasks=scheduled,
            deferred=tuple(deferred),
            budget_remaining=budget_remaining,
        )
