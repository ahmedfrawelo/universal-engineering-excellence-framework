"""Persisted host lifecycle controller with bounded convergence and recovery."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol

from .adapters import DispatchContract, get_adapter
from .errors import WorkflowError
from .model import TaskGraph
from .orchestration import HostResult
from .scheduler import Scheduler
from .state import StateStore, TaskStatus
from .verification import Verifier

_OPERATIONS = frozenset({"dispatch", "poll", "heartbeat", "cancel", "close"})


class LifecycleRuntime(Protocol):
    @property
    def capabilities(self) -> frozenset[str]: ...

    def dispatch(self, contract: DispatchContract) -> str: ...
    def poll(self, handle: str) -> HostResult | None: ...
    def heartbeat(self, handle: str) -> None: ...
    def cancel(self, handle: str) -> None: ...
    def close(self, handle: str) -> None: ...


@dataclass(frozen=True)
class ControllerReport:
    cycles: int
    status: str
    dispatched: int
    applied: int
    reclaimed: int
    progress: bool

    def to_dict(self) -> dict[str, object]:
        return {
            "schemaVersion": 2,
            "cycles": self.cycles,
            "status": self.status,
            "dispatched": self.dispatched,
            "applied": self.applied,
            "reclaimed": self.reclaimed,
            "progress": self.progress,
        }


class Controller:
    def __init__(
        self,
        graph: TaskGraph,
        runtime: LifecycleRuntime,
        adapter: str = "generic",
        verifier: Verifier | None = None,
    ) -> None:
        unknown = set(runtime.capabilities) - _OPERATIONS
        if unknown:
            raise WorkflowError(
                "runtime declares unknown capabilities: " + ", ".join(sorted(unknown))
            )
        if not {"dispatch", "poll"}.issubset(runtime.capabilities):
            raise WorkflowError("controller runtime requires dispatch and poll capabilities")
        self.graph = graph
        self.runtime = runtime
        self.adapter = get_adapter(adapter)
        self.verifier = verifier

    def _contract(self, state, task_id: str) -> DispatchContract:
        run = state.tasks[task_id]
        task = self.graph.task_map[task_id]
        return DispatchContract(
            adapter=self.adapter.name,
            task_id=task_id,
            worker=run.assigned_worker or "",
            prompt=f"Execute {task.id}: {task.title}.",
            ownership={
                "readOnly": task.read_only,
                "allowedWriteSet": list(task.write_set),
                "forbiddenPaths": list(task.forbidden_paths),
            },
            required_capabilities=task.capabilities,
            acceptance=task.acceptance,
            transport=self.adapter.transport,
            result_protocol=self.adapter.result_protocol,
            workflow_id=self.graph.workflow_id,
            execution_id=state.execution_id,
            graph_digest=self.graph.digest,
            route_digest=self.graph.route_digest or self.graph.digest,
            execution_spec_digest=self.graph.execution_spec_digest or self.graph.digest,
            attempt_id=run.attempt_id or "",
            lease_generation=run.lease_generation,
            fencing_token=run.fencing_token or "",
            shell_policy=self.graph.policy.shell_policy,
            allowed_shell_commands=self.graph.policy.allowed_shell_commands,
        )

    def run(self, store: StateStore, *, max_cycles: int = 100) -> ControllerReport:
        if not 1 <= max_cycles <= 10000:
            raise WorkflowError("max_cycles must be from 1 through 10000")
        totals = {"dispatched": 0, "applied": 0, "reclaimed": 0}
        any_progress = False
        for cycle in range(1, max_cycles + 1):
            state = store.load(self.graph)
            cycle_progress = False
            previous = state.revision
            reclaimed = state.reclaim_expired(self.graph)
            if reclaimed:
                store.save(state, expected_revision=previous)
                totals["reclaimed"] += len(reclaimed)
                cycle_progress = True

            decision = Scheduler(self.graph).decide(state)
            if decision.tasks:
                previous = state.revision
                state.reserve_wave(
                    [(item.task_id, item.worker) for item in decision.tasks],
                    decision.desired_workers,
                )
                store.save(state, expected_revision=previous)
                contracts = self.adapter.build(self.graph, decision, state)
                for contract in contracts:
                    handle = self.runtime.dispatch(contract)
                    if not isinstance(handle, str) or not handle.strip():
                        raise WorkflowError("runtime dispatch must return a non-empty handle")
                    previous = state.revision
                    run = state.tasks[contract.task_id]
                    if run.attempt_id != contract.attempt_id:
                        raise WorkflowError("attempt changed during host dispatch")
                    run.host_handle = handle.strip()
                    state.transition(self.graph, contract.task_id, "start", worker=contract.worker)
                    store.save(state, expected_revision=previous)
                    totals["dispatched"] += 1
                    cycle_progress = True

            for task_id, run in list(state.tasks.items()):
                if run.status != TaskStatus.RESERVED or run.host_handle:
                    continue
                contract = self._contract(state, task_id)
                handle = self.runtime.dispatch(contract)
                if not isinstance(handle, str) or not handle.strip():
                    raise WorkflowError("runtime dispatch must return a non-empty handle")
                previous = state.revision
                run.host_handle = handle.strip()
                state.transition(self.graph, task_id, "start", worker=contract.worker)
                store.save(state, expected_revision=previous)
                totals["dispatched"] += 1
                cycle_progress = True

            for task_id, run in list(state.tasks.items()):
                if run.status != TaskStatus.RUNNING or not run.host_handle:
                    continue
                result = self.runtime.poll(run.host_handle)
                if result is None:
                    if "heartbeat" in self.runtime.capabilities:
                        self.runtime.heartbeat(run.host_handle)
                        previous = state.revision
                        state.heartbeat(task_id, run.attempt_id or "", run.fencing_token or "")
                        store.save(state, expected_revision=previous)
                        cycle_progress = True
                    continue
                contract = self._contract(state, task_id)
                result.validate()
                result.assert_matches(contract)
                result.assert_acceptance_evidence(contract)
                previous = state.revision
                state.transition(
                    self.graph,
                    task_id,
                    result.outcome,
                    worker=contract.worker,
                    evidence=result.evidence,
                    error=result.error,
                    tokens=result.tokens,
                )
                store.save(state, expected_revision=previous)
                if "close" in self.runtime.capabilities:
                    self.runtime.close(run.host_handle)
                totals["applied"] += 1
                cycle_progress = True

            state = store.load(self.graph)
            any_progress = any_progress or cycle_progress
            if state.overall_status == "VERIFYING":
                if self.verifier is None:
                    return ControllerReport(cycle, "VERIFYING", **totals, progress=any_progress)
                report = self.verifier.verify(self.graph, state)
                previous = state.revision
                state.record_verification(
                    passed=report.passed,
                    evidence=report.evidence,
                    diff_digest=report.diff_digest,
                    independent=report.independent,
                )
                store.save(state, expected_revision=previous)
                cycle_progress = True
                any_progress = True
                state = store.load(self.graph)
            if state.overall_status in {"DONE", "FAILED", "BLOCKED", "NEEDS_REPLAN"}:
                return ControllerReport(
                    cycle, state.overall_status, **totals, progress=any_progress
                )
            if not cycle_progress:
                return ControllerReport(
                    cycle, state.overall_status, **totals, progress=any_progress
                )
        state = store.load(self.graph)
        return ControllerReport(max_cycles, state.overall_status, **totals, progress=any_progress)

    def cancel_active(self, store: StateStore, *, reason: str) -> tuple[str, ...]:
        if "cancel" not in self.runtime.capabilities:
            raise WorkflowError("runtime does not support cancel")
        if not reason.strip():
            raise WorkflowError("cancellation requires a reason")
        state = store.load(self.graph)
        cancelled: list[str] = []
        for task_id, run in state.tasks.items():
            if run.status not in {TaskStatus.RESERVED, TaskStatus.RUNNING} or not run.host_handle:
                continue
            self.runtime.cancel(run.host_handle)
            previous = state.revision
            state.transition(self.graph, task_id, "block", error=reason.strip())
            store.save(state, expected_revision=previous)
            if "close" in self.runtime.capabilities:
                self.runtime.close(run.host_handle)
            cancelled.append(task_id)
        return tuple(cancelled)
