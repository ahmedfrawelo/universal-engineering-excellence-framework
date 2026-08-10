"""Explicit host-runtime orchestration without hidden command execution."""

from __future__ import annotations

import json
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
    tokens: int | None = None
    workflow_id: str = ""
    execution_id: str = ""
    graph_digest: str = ""
    route_digest: str = ""
    execution_spec_digest: str = ""
    attempt_id: str = ""
    lease_generation: int = 0
    fencing_token: str = ""

    @classmethod
    def for_contract(cls, contract: DispatchContract, outcome: str, **values: Any) -> HostResult:
        return cls(
            task_id=contract.task_id,
            worker=contract.worker,
            outcome=outcome,
            workflow_id=contract.workflow_id,
            execution_id=contract.execution_id,
            graph_digest=contract.graph_digest,
            route_digest=contract.route_digest,
            execution_spec_digest=contract.execution_spec_digest,
            attempt_id=contract.attempt_id,
            lease_generation=contract.lease_generation,
            fencing_token=contract.fencing_token,
            **values,
        )

    def validate(self) -> None:
        if self.outcome not in {"complete", "fail", "block"}:
            raise WorkflowError(f"unsupported host outcome: {self.outcome}")
        if self.outcome == "complete" and not self.evidence.strip():
            raise WorkflowError("host completion requires evidence")
        if self.tokens is not None and (
            isinstance(self.tokens, bool) or not isinstance(self.tokens, int) or self.tokens < 0
        ):
            raise WorkflowError("host result tokens must be non-negative")

    def assert_matches(self, contract: DispatchContract) -> None:
        expected = (
            contract.task_id,
            contract.worker,
            contract.workflow_id,
            contract.execution_id,
            contract.graph_digest,
            contract.route_digest,
            contract.execution_spec_digest,
            contract.attempt_id,
            contract.lease_generation,
            contract.fencing_token,
        )
        actual = (
            self.task_id,
            self.worker,
            self.workflow_id,
            self.execution_id,
            self.graph_digest,
            self.route_digest,
            self.execution_spec_digest,
            self.attempt_id,
            self.lease_generation,
            self.fencing_token,
        )
        names = (
            "taskId",
            "worker",
            "workflowId",
            "executionId",
            "graphDigest",
            "routeDigest",
            "executionSpecDigest",
            "attemptId",
            "leaseGeneration",
            "fencingToken",
        )
        mismatches = [
            name
            for name, left, right in zip(names, actual, expected, strict=True)
            if left != right
        ]
        if mismatches:
            raise WorkflowError("host result identity mismatch: " + ", ".join(mismatches))

    def assert_acceptance_evidence(self, contract: DispatchContract) -> None:
        """Bind completion evidence to every acceptance identifier."""
        if self.outcome != "complete":
            return
        try:
            evidence = json.loads(self.evidence)
        except json.JSONDecodeError as exc:
            raise WorkflowError(
                "host completion evidence must be a JSON object keyed by acceptance identifiers"
            ) from exc
        if not isinstance(evidence, dict) or any(
            not isinstance(key, str)
            or not isinstance(value, str)
            or not value.strip()
            for key, value in evidence.items()
        ):
            raise WorkflowError(
                "host completion evidence must map acceptance identifiers to non-empty receipts"
            )
        expected = set(contract.acceptance)
        actual = set(evidence)
        if actual != expected:
            raise WorkflowError(
                "host completion evidence acceptance mismatch: "
                f"missing={sorted(expected - actual)}, unknown={sorted(actual - expected)}"
            )


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
        if not isinstance(document, dict) or document.get("schemaVersion") != 2:
            raise WorkflowError(
                "host result document schemaVersion must be 2; v1 receipts are not "
                "fence-safe and must be redispatched"
            )
        records = document.get("results")
        if not isinstance(records, list) or not records:
            raise WorkflowError("host result document requires results")
        self._results: dict[tuple[str, str, str], HostResult] = {}
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
                    tokens=record.get("tokens"),
                    workflow_id=record["workflowId"],
                    execution_id=record["executionId"],
                    graph_digest=record["graphDigest"],
                    route_digest=record["routeDigest"],
                    execution_spec_digest=record["executionSpecDigest"],
                    attempt_id=record["attemptId"],
                    lease_generation=record["leaseGeneration"],
                    fencing_token=record["fencingToken"],
                )
            except KeyError as exc:
                raise WorkflowError(f"results[{index}] is missing {exc.args[0]}") from exc
            if not isinstance(result.task_id, str) or not isinstance(result.worker, str):
                raise WorkflowError(f"results[{index}] taskId and worker must be strings")
            result.validate()
            key = (result.task_id, result.worker, result.attempt_id)
            if key in self._results:
                raise WorkflowError(f"duplicate host result for {result.task_id}/{result.worker}")
            self._results[key] = result

    def execute(self, contract: DispatchContract) -> HostResult:
        try:
            result = self._results[(contract.task_id, contract.worker, contract.attempt_id)]
            result.assert_matches(contract)
            result.assert_acceptance_evidence(contract)
            return result
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
        state.reserve_wave(
            [(item.task_id, item.worker) for item in decision.tasks],
            decision.desired_workers,
        )
        contracts = tuple(self.adapter.build(self.graph, decision, state))
        results: list[HostResult] = []
        for contract in contracts:
            state.transition(self.graph, contract.task_id, "start", worker=contract.worker)
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
            try:
                result.assert_matches(contract)
                result.assert_acceptance_evidence(contract)
            except WorkflowError:
                state.transition(
                    self.graph,
                    contract.task_id,
                    "fail",
                    worker=contract.worker,
                    error="host result does not match its dispatch contract",
                )
                raise
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

    def run_persisted_wave(self, store: StateStore, runtime: HostRuntime) -> OrchestrationReport:
        """Persist reservation, start, and result boundaries for crash-safe resume."""
        state = store.load(self.graph)
        decision = Scheduler(self.graph).decide(state)
        previous = state.revision
        state.reserve_wave(
            [(item.task_id, item.worker) for item in decision.tasks],
            decision.desired_workers,
        )
        contracts = tuple(self.adapter.build(self.graph, decision, state))
        store.save(state, expected_revision=previous)
        self._event(
            store,
            state,
            "wave-reserved",
            desiredWorkers=decision.desired_workers,
            taskIds=[contract.task_id for contract in contracts],
        )
        results: list[HostResult] = []
        for contract in contracts:
            previous = state.revision
            state.transition(self.graph, contract.task_id, "start", worker=contract.worker)
            store.save(state, expected_revision=previous)
            self._event(
                store,
                state,
                "task-started",
                taskId=contract.task_id,
                worker=contract.worker,
                transport=contract.transport,
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
            try:
                result.assert_matches(contract)
                result.assert_acceptance_evidence(contract)
            except WorkflowError:
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
            self._event(
                store,
                state,
                "task-result",
                taskId=contract.task_id,
                worker=contract.worker,
                outcome=result.outcome,
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
            state.assert_live_lease(task_id)
            task = self.graph.task_map[task_id]
            contract = DispatchContract(
                adapter=self.adapter.name,
                task_id=task_id,
                worker=run.assigned_worker,
                prompt="host result application only",
                ownership={
                    "readOnly": task.read_only,
                    "allowedWriteSet": list(task.write_set),
                    "forbiddenPaths": list(task.forbidden_paths),
                },
                required_capabilities=task.capabilities,
                acceptance=task.acceptance,
                shell_policy=self.graph.policy.shell_policy,
                allowed_shell_commands=self.graph.policy.allowed_shell_commands,
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
            )
            result = runtime.execute(contract)
            result.validate()
            result.assert_matches(contract)
            result.assert_acceptance_evidence(contract)
            previous = state.revision
            state.transition(self.graph, task_id, "start", worker=contract.worker)
            store.save(state, expected_revision=previous)
            self._event(
                store,
                state,
                "task-started",
                taskId=task_id,
                worker=contract.worker,
                transport=contract.transport,
            )
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
            self._event(
                store,
                state,
                "task-result",
                taskId=task_id,
                worker=contract.worker,
                outcome=result.outcome,
                evidence=result.evidence,
                error=result.error,
                tokens=result.tokens,
            )
            results.append(result)
        return tuple(results)

    def _event(self, store: StateStore, state: ExecutionState, kind: str, **fields: object) -> None:
        store.append_event(
            {
                "schemaVersion": 1,
                "timestamp": state.updated_at,
                "workflowId": self.graph.workflow_id,
                "graphDigest": self.graph.digest,
                "revision": state.revision,
                "kind": kind,
                **fields,
            }
        )
