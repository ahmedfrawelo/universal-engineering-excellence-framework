"""Explicit host-runtime orchestration without hidden command execution."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Protocol

from .adapters import DispatchContract, get_adapter
from .errors import WorkflowError
from .model import TaskGraph
from .scheduler import Scheduler
from .state import ExecutionState, StateStore


@dataclass(frozen=True)
class HostResult:
    task_id: str
    worker: str
    outcome: str
    evidence: str = ""
    error: str = ""
    tokens: int = 0

    def validate(self) -> None:
        if self.outcome not in {"complete", "fail", "block"}:
            raise WorkflowError(f"unsupported host outcome: {self.outcome}")
        if self.outcome == "complete" and not self.evidence.strip():
            raise WorkflowError("host completion requires evidence")
        if self.tokens < 0:
            raise WorkflowError("host result tokens must be non-negative")


class HostRuntime(Protocol):
    """The host explicitly owns agent creation and returns bounded results."""

    def execute(self, contract: DispatchContract) -> HostResult: ...


class RecordedHostRuntime:
    """Explicit result importer for a host that already executed contracts.

    This is deliberately not an agent launcher. A native host owns execution,
    exports bounded results, and this runtime applies only the contract-matched
    receipt to durable UEEF state.
    """

    def __init__(self, document: Any) -> None:
        if not isinstance(document, dict) or document.get("schemaVersion") != 1:
            raise WorkflowError("host result document schemaVersion must be 1")
        records = document.get("results")
        if not isinstance(records, list) or not records:
            raise WorkflowError("host result document requires results")
        self._results: dict[tuple[str, str], HostResult] = {}
        for index, record in enumerate(records):
            if not isinstance(record, dict):
                raise WorkflowError(f"results[{index}] must be an object")
            try:
                result = HostResult(
                    task_id=record["taskId"],
                    worker=record["worker"],
                    outcome=record["outcome"],
                    evidence=record.get("evidence", ""),
                    error=record.get("error", ""),
                    tokens=record.get("tokens", 0),
                )
            except KeyError as exc:
                raise WorkflowError(f"results[{index}] is missing {exc.args[0]}") from exc
            if not isinstance(result.task_id, str) or not isinstance(result.worker, str):
                raise WorkflowError(f"results[{index}] taskId and worker must be strings")
            result.validate()
            key = (result.task_id, result.worker)
            if key in self._results:
                raise WorkflowError(f"duplicate host result for {result.task_id}/{result.worker}")
            self._results[key] = result

    def execute(self, contract: DispatchContract) -> HostResult:
        try:
            return self._results[(contract.task_id, contract.worker)]
        except KeyError as exc:
            raise WorkflowError(
                f"host result missing for {contract.task_id}/{contract.worker}"
            ) from exc


@dataclass(frozen=True)
class OrchestrationReport:
    contracts: tuple[DispatchContract, ...]
    results: tuple[HostResult, ...]
    desired_workers: int
    scale_action: str


class Orchestrator:
    def __init__(self, graph: TaskGraph, adapter: str = "generic") -> None:
        self.graph = graph
        self.adapter = get_adapter(adapter)

    def run_wave(self, state: ExecutionState, runtime: HostRuntime) -> OrchestrationReport:
        decision = Scheduler(self.graph).decide(state)
        contracts = tuple(self.adapter.build(self.graph, decision))
        state.reserve_wave(
            [(item.task_id, item.worker) for item in decision.tasks],
            decision.desired_workers,
        )
        results: list[HostResult] = []
        for contract in contracts:
            state.transition(
                self.graph, contract.task_id, "start", worker=contract.worker
            )
            try:
                result = runtime.execute(contract)
                result.validate()
            except Exception as exc:
                result = HostResult(
                    contract.task_id,
                    contract.worker,
                    "fail",
                    error=str(exc)[:4000] or type(exc).__name__,
                )
                state.transition(
                    self.graph,
                    contract.task_id,
                    "fail",
                    worker=contract.worker,
                    error=result.error,
                )
                results.append(result)
                continue
            if result.task_id != contract.task_id or result.worker != contract.worker:
                state.transition(
                    self.graph,
                    contract.task_id,
                    "fail",
                    worker=contract.worker,
                    error="host result does not match its dispatch contract",
                )
                raise WorkflowError("host result does not match its dispatch contract")
            state.transition(
                self.graph,
                contract.task_id,
                result.outcome,
                worker=contract.worker,
                evidence=result.evidence,
                error=result.error,
                tokens=result.tokens,
            )
            results.append(result)
        return OrchestrationReport(
            contracts=contracts,
            results=tuple(results),
            desired_workers=decision.desired_workers,
            scale_action=decision.scale_action,
        )

    def run_persisted_wave(
        self, store: StateStore, runtime: HostRuntime
    ) -> OrchestrationReport:
        """Persist reservation, start, and result boundaries for crash-safe resume."""
        state = store.load(self.graph)
        decision = Scheduler(self.graph).decide(state)
        contracts = tuple(self.adapter.build(self.graph, decision))
        previous = state.revision
        state.reserve_wave(
            [(item.task_id, item.worker) for item in decision.tasks],
            decision.desired_workers,
        )
        store.save(state, expected_revision=previous)
        self._event(store, state, "wave-reserved", desiredWorkers=decision.desired_workers,
                    taskIds=[contract.task_id for contract in contracts])
        results: list[HostResult] = []
        for contract in contracts:
            previous = state.revision
            state.transition(
                self.graph, contract.task_id, "start", worker=contract.worker
            )
            store.save(state, expected_revision=previous)
            self._event(store, state, "task-started", taskId=contract.task_id,
                        worker=contract.worker, transport=contract.transport)
            try:
                result = runtime.execute(contract)
                result.validate()
            except Exception as exc:
                result = HostResult(
                    contract.task_id,
                    contract.worker,
                    "fail",
                    error=str(exc)[:4000] or type(exc).__name__,
                )
            if result.task_id != contract.task_id or result.worker != contract.worker:
                result = HostResult(
                    contract.task_id,
                    contract.worker,
                    "fail",
                    error="host result does not match its dispatch contract",
                )
            previous = state.revision
            state.transition(
                self.graph,
                contract.task_id,
                result.outcome,
                worker=contract.worker,
                evidence=result.evidence,
                error=result.error,
                tokens=result.tokens,
            )
            store.save(state, expected_revision=previous)
            self._event(store, state, "task-result", taskId=contract.task_id,
                        worker=contract.worker, outcome=result.outcome,
                        evidence=result.evidence, error=result.error, tokens=result.tokens)
            results.append(result)
        return OrchestrationReport(
            contracts=contracts,
            results=tuple(results),
            desired_workers=decision.desired_workers,
            scale_action=decision.scale_action,
        )

    def apply_persisted_results(
        self, store: StateStore, runtime: HostRuntime
    ) -> tuple[HostResult, ...]:
        """Apply receipts to an already reserved wave without rescheduling it.

        A host obtains contracts through ``schedule``, creates native workers,
        and then calls this method through the CLI. This preserves the original
        reservation and blocks a second scheduler from stealing the work.
        """

        state = store.load(self.graph)
        results: list[HostResult] = []
        for task_id, run in state.tasks.items():
            if run.status.value != "RESERVED" or not run.assigned_worker:
                continue
            contract = DispatchContract(
                adapter=self.adapter.name,
                task_id=task_id,
                worker=run.assigned_worker,
                prompt="host result application only",
                ownership={},
                required_capabilities=(),
                acceptance=(),
                transport=self.adapter.transport,
                result_protocol=self.adapter.result_protocol,
            )
            previous = state.revision
            state.transition(self.graph, task_id, "start", worker=contract.worker)
            store.save(state, expected_revision=previous)
            self._event(store, state, "task-started", taskId=task_id,
                        worker=contract.worker, transport=contract.transport)
            try:
                result = runtime.execute(contract)
                result.validate()
            except Exception as exc:
                result = HostResult(task_id, contract.worker, "fail", error=str(exc)[:4000])
            if result.task_id != task_id or result.worker != contract.worker:
                result = HostResult(
                    task_id, contract.worker, "fail", error="host result does not match reservation"
                )
            previous = state.revision
            state.transition(
                self.graph, task_id, result.outcome, worker=contract.worker,
                evidence=result.evidence, error=result.error, tokens=result.tokens
            )
            store.save(state, expected_revision=previous)
            self._event(store, state, "task-result", taskId=task_id,
                        worker=contract.worker, outcome=result.outcome,
                        evidence=result.evidence, error=result.error, tokens=result.tokens)
            results.append(result)
        return tuple(results)

    def _event(self, store: StateStore, state: ExecutionState, kind: str, **fields: object) -> None:
        store.append_event({
            "schemaVersion": 1,
            "timestamp": state.updated_at,
            "workflowId": self.graph.workflow_id,
            "graphDigest": self.graph.digest,
            "revision": state.revision,
            "kind": kind,
            **fields,
        })
