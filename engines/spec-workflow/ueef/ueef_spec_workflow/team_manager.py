"""Safe, host-owned dynamic team management for persisted workflow graphs.

The manager deliberately plans and records work; it cannot run commands or
create agents.  A native host receives its explicit contracts and owns the
worker lifecycle.
"""

from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass, replace
from typing import Any

from .adapters import DispatchContract, get_adapter
from .errors import WorkflowError
from .model import TaskGraph, TaskSpec
from .scheduler import ScheduleDecision, Scheduler
from .state import ExecutionState, StateStore, TaskStatus


@dataclass(frozen=True)
class WorkerProfile:
    """A non-executable description of one host worker that may receive work."""

    worker_id: str
    capabilities: tuple[str, ...]
    available: bool = True

    @classmethod
    def from_dict(cls, value: Any, index: int) -> WorkerProfile:
        if not isinstance(value, dict):
            raise WorkflowError(f"workers[{index}] must be an object")
        worker_id = value.get("id")
        capabilities = value.get("capabilities", [])
        available = value.get("available", True)
        if not isinstance(worker_id, str) or not worker_id.strip() or len(worker_id.strip()) > 128:
            raise WorkflowError(f"workers[{index}].id must be a bounded non-empty string")
        valid_capabilities = isinstance(capabilities, list) and all(
            isinstance(item, str) and item.strip() for item in capabilities
        )
        if not valid_capabilities:
            raise WorkflowError(
                f"workers[{index}].capabilities must be an array of non-empty strings"
            )
        normalized_capabilities = {item.strip().casefold() for item in capabilities}
        if len(capabilities) > 128 or len(normalized_capabilities) != len(capabilities):
            raise WorkflowError(
                f"workers[{index}].capabilities contains duplicates or too many entries"
            )
        if not isinstance(available, bool):
            raise WorkflowError(f"workers[{index}].available must be boolean")
        return cls(worker_id.strip(), tuple(item.strip() for item in capabilities), available)

    def supports(self, required: tuple[str, ...]) -> bool:
        actual = {item.casefold() for item in self.capabilities}
        return all(item.casefold() in actual for item in required)


@dataclass(frozen=True)
class ManagementAction:
    kind: str
    task_id: str | None
    detail: str

    def to_dict(self) -> dict[str, str | None]:
        return {"kind": self.kind, "taskId": self.task_id, "detail": self.detail}


@dataclass(frozen=True)
class ManagementReport:
    decision: ScheduleDecision
    contracts: tuple[DispatchContract, ...]
    actions: tuple[ManagementAction, ...]

    def to_dict(self) -> dict[str, Any]:
        data = self.decision.to_dict()
        data["dispatchContracts"] = [contract.to_dict() for contract in self.contracts]
        data["managementActions"] = [action.to_dict() for action in self.actions]
        return data


class TeamManager:
    """Derive bounded worker, reroute, review, and integration decisions.

    A task that declares ``verifier`` or ``integration`` capability is treated
    as a final phase.  This supplements explicit graph dependencies: it cannot
    run until the relevant preceding work has completed.
    """

    def __init__(self, graph: TaskGraph, adapter: str = "generic") -> None:
        self.graph = graph
        self.adapter = get_adapter(adapter)

    @staticmethod
    def parse_workers(document: Any) -> tuple[WorkerProfile, ...]:
        if not isinstance(document, dict) or document.get("schemaVersion") != 1:
            raise WorkflowError("worker catalog schemaVersion must be 1")
        raw_workers = document.get("workers")
        if not isinstance(raw_workers, list) or not raw_workers:
            raise WorkflowError("worker catalog requires a non-empty workers array")
        workers = tuple(
            WorkerProfile.from_dict(item, index) for index, item in enumerate(raw_workers)
        )
        ids = [worker.worker_id.casefold() for worker in workers]
        if len(set(ids)) != len(ids):
            raise WorkflowError("worker catalog contains duplicate IDs")
        return workers

    @staticmethod
    def _phase(task: TaskSpec) -> str:
        capabilities = {item.casefold() for item in task.capabilities}
        if "integration" in capabilities:
            return "integration"
        if "verifier" in capabilities:
            return "verifier"
        return "execution"

    def _phase_allowed(self, task: TaskSpec, state: ExecutionState) -> tuple[bool, str]:
        phase = self._phase(task)
        if phase == "execution":
            return True, ""
        if phase == "verifier":
            others = [
                other
                for other in self.graph.tasks
                if other.id != task.id and self._phase(other) == "execution"
            ]
        else:
            others = [other for other in self.graph.tasks if other.id != task.id]
        incomplete = [
            other.id for other in others if state.tasks[other.id].status != TaskStatus.DONE
        ]
        if incomplete:
            return False, f"{phase} waits for completed tasks: {', '.join(sorted(incomplete))}"
        return True, ""

    @staticmethod
    def _reroute_actions(state: ExecutionState) -> list[ManagementAction]:
        actions: list[ManagementAction] = []
        for task_id, run in sorted(state.tasks.items()):
            if run.status == TaskStatus.BLOCKED and run.block_kind == "manual":
                actions.append(
                    ManagementAction("ESCALATE_BLOCKER", task_id, run.last_error or "manual block")
                )
            elif run.status == TaskStatus.READY and run.attempts > 0 and run.last_error:
                actions.append(ManagementAction("REROUTE", task_id, run.last_error))
            elif run.status == TaskStatus.FAILED:
                actions.append(
                    ManagementAction(
                        "ESCALATE_FAILURE",
                        task_id,
                        run.last_error or "retry limit exhausted",
                    )
                )
        return actions

    def plan(self, state: ExecutionState, workers: tuple[WorkerProfile, ...]) -> ManagementReport:
        decision = Scheduler(self.graph).decide(state)
        available = [worker for worker in workers if worker.available]
        busy = {
            run.assigned_worker.casefold()
            for run in state.tasks.values()
            if run.status in {TaskStatus.RESERVED, TaskStatus.RUNNING} and run.assigned_worker
        }
        available = [worker for worker in available if worker.worker_id.casefold() not in busy]
        preview_state = deepcopy(state)
        preview_state.reserve_wave(
            [(item.task_id, item.worker) for item in decision.tasks],
            decision.desired_workers,
        )
        source_contracts = self.adapter.build(self.graph, decision, preview_state)
        contracts: list[DispatchContract] = []
        actions = self._reroute_actions(state)
        for contract in source_contracts:
            task = self.graph.task_map[contract.task_id]
            allowed, reason = self._phase_allowed(task, state)
            if not allowed:
                actions.append(ManagementAction("DEFER_PHASE", task.id, reason))
                continue
            match = next(
                (worker for worker in available if worker.supports(task.capabilities)),
                None,
            )
            if match is None:
                required = ", ".join(task.capabilities) or "no declared capability"
                actions.append(
                    ManagementAction(
                        "WAIT_FOR_WORKER",
                        task.id,
                        f"no available worker supports: {required}",
                    )
                )
                continue
            available.remove(match)
            phase = self._phase(task)
            prompt = contract.prompt + f" Management phase: {phase}."
            contracts.append(
                DispatchContract(
                    adapter=contract.adapter,
                    task_id=contract.task_id,
                    worker=match.worker_id,
                    prompt=prompt,
                    ownership=contract.ownership,
                    required_capabilities=contract.required_capabilities,
                    acceptance=contract.acceptance,
                    transport=contract.transport,
                    result_protocol=contract.result_protocol,
                    workflow_id=contract.workflow_id,
                    execution_id=contract.execution_id,
                    graph_digest=contract.graph_digest,
                    route_digest=contract.route_digest,
                    execution_spec_digest=contract.execution_spec_digest,
                    attempt_id=contract.attempt_id,
                    lease_generation=contract.lease_generation,
                    fencing_token=contract.fencing_token,
                    shell_policy=contract.shell_policy,
                    allowed_shell_commands=contract.allowed_shell_commands,
                )
            )
            actions.append(
                ManagementAction("DISPATCH", task.id, f"{phase} assigned to {match.worker_id}")
            )
        assignment_mode = (
            "host-catalog-validated"
            if len(contracts) == len(source_contracts)
            else "host-catalog-partial"
        )
        return ManagementReport(
            replace(decision, assignment_mode=assignment_mode),
            tuple(contracts),
            tuple(actions),
        )

    def manage_persisted(
        self,
        store: StateStore,
        workers: tuple[WorkerProfile, ...],
        *,
        commit: bool = False,
    ) -> ManagementReport:
        state = store.load(self.graph)
        stolen: list[ManagementAction] = []
        stolen_task_ids: set[str] = set()
        if commit:
            availability = {worker.worker_id.casefold(): worker for worker in workers}
            busy_workers = {
                (run.assigned_worker or "").casefold()
                for run in state.tasks.values()
                if run.status in {TaskStatus.RESERVED, TaskStatus.RUNNING}
                and run.assigned_worker
                and availability.get(run.assigned_worker.casefold()) is not None
                and availability[run.assigned_worker.casefold()].available
            }
            replacements = [
                worker
                for worker in workers
                if worker.available and worker.worker_id.casefold() not in busy_workers
            ]
            previous = state.revision
            for task_id, run in sorted(state.tasks.items()):
                assigned = (run.assigned_worker or "").casefold()
                owner = availability.get(assigned)
                if (
                    run.status != TaskStatus.RESERVED
                    or run.host_handle
                    or (owner and owner.available)
                ):
                    continue
                task = self.graph.task_map[task_id]
                replacement = next(
                    (
                        worker
                        for worker in replacements
                        if worker.worker_id.casefold() != assigned
                        and worker.supports(task.capabilities)
                    ),
                    None,
                )
                if replacement is None:
                    continue
                old_worker = run.assigned_worker or ""
                state.steal_unstarted_reservation(
                    self.graph,
                    task_id,
                    from_worker=old_worker,
                    to_worker=replacement.worker_id,
                )
                replacements.remove(replacement)
                stolen.append(
                    ManagementAction(
                        "WORK_STEAL",
                        task_id,
                        f"unstarted reservation moved from {old_worker} to {replacement.worker_id}",
                    )
                )
                stolen_task_ids.add(task_id)
            if stolen:
                store.save(state, expected_revision=previous)
        report = self.plan(state, workers)
        if commit and stolen:
            stolen_contracts = tuple(
                contract
                for contract in self.adapter.build_reserved(self.graph, state)
                if contract.task_id in stolen_task_ids
            )
            report = ManagementReport(
                report.decision,
                stolen_contracts + report.contracts,
                tuple(stolen) + report.actions,
            )
        if commit and report.contracts:
            previous = state.revision
            new_reservations = [
                (contract.task_id, contract.worker)
                for contract in report.contracts
                if state.tasks[contract.task_id].status == TaskStatus.READY
            ]
            if new_reservations:
                state.reserve_wave(
                    new_reservations,
                    report.decision.desired_workers,
                )
                store.save(state, expected_revision=previous)
            committed_contracts = []
            for contract in report.contracts:
                run = state.tasks[contract.task_id]
                committed_contracts.append(
                    replace(
                        contract,
                        execution_id=state.execution_id,
                        attempt_id=run.attempt_id or "",
                        lease_generation=run.lease_generation,
                        fencing_token=run.fencing_token or "",
                    )
                )
            report = ManagementReport(report.decision, tuple(committed_contracts), report.actions)
        store.append_event(
            {
                "schemaVersion": 1,
                "timestamp": state.updated_at,
                "workflowId": self.graph.workflow_id,
                "graphDigest": self.graph.digest,
                "revision": state.revision,
                "kind": "team-management-cycle",
                "committed": commit,
                "contracts": [contract.task_id for contract in report.contracts],
                "actions": [action.to_dict() for action in report.actions],
            }
        )
        return report
