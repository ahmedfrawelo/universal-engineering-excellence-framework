"""Host-neutral dispatch contracts for scheduled tasks."""

from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Any

from .errors import WorkflowError
from .model import TaskGraph
from .scheduler import ScheduleDecision, ScheduledTask
from .state import ExecutionState, TaskStatus


@dataclass(frozen=True)
class DispatchContract:
    adapter: str
    task_id: str
    worker: str
    prompt: str
    ownership: dict[str, Any]
    required_capabilities: tuple[str, ...]
    acceptance: tuple[str, ...]
    transport: str
    result_protocol: str
    workflow_id: str
    execution_id: str
    graph_digest: str
    route_digest: str
    execution_spec_digest: str
    attempt_id: str
    lease_generation: int
    fencing_token: str
    shell_policy: str = "deny"
    allowed_shell_commands: tuple[str, ...] = ()

    def assert_shell_command_allowed(self, command: str) -> None:
        """Fail closed unless the exact command is present in an allowlist."""
        if not isinstance(command, str) or not command.strip():
            raise WorkflowError("shell command must be a non-empty string")
        if self.shell_policy != "allowlist":
            raise WorkflowError("dispatch contract denies shell commands")
        if command.strip() not in self.allowed_shell_commands:
            raise WorkflowError("shell command is not present in the dispatch allowlist")

    def to_dict(self) -> dict[str, Any]:
        return {
            "adapter": self.adapter,
            "taskId": self.task_id,
            "worker": self.worker,
            "prompt": self.prompt,
            "ownership": self.ownership,
            "requiredCapabilities": list(self.required_capabilities),
            "acceptance": list(self.acceptance),
            "transport": self.transport,
            "resultProtocol": self.result_protocol,
            "workflowId": self.workflow_id,
            "executionId": self.execution_id,
            "graphDigest": self.graph_digest,
            "routeDigest": self.route_digest,
            "executionSpecDigest": self.execution_spec_digest,
            "attemptId": self.attempt_id,
            "leaseGeneration": self.lease_generation,
            "fencingToken": self.fencing_token,
            "shellPolicy": self.shell_policy,
            "allowedShellCommands": list(self.allowed_shell_commands),
        }


class HostAdapter:
    name = "generic"
    transport = "external"
    result_protocol = "ueef-host-result/v2"
    capabilities = frozenset({"external-receipt-import"})

    def build(
        self, graph: TaskGraph, decision: ScheduleDecision, state: ExecutionState
    ) -> list[DispatchContract]:
        task_map = graph.task_map
        contracts: list[DispatchContract] = []
        for scheduled in decision.tasks:
            task = task_map[scheduled.task_id]
            run = state.tasks[task.id]
            if not run.attempt_id or not run.fencing_token:
                raise WorkflowError(
                    f"{task.id} must be reserved before building a dispatch contract"
                )
            ownership = {
                "readOnly": task.read_only,
                "allowedWriteSet": list(task.write_set),
                "forbiddenPaths": list(task.forbidden_paths),
            }
            prompt = (
                f"Execute {task.id}: {task.title}. "
                f"Dependencies are complete: {', '.join(task.depends_on) or 'none'}. "
                "Stay inside the ownership contract and return acceptance evidence."
            )
            if graph.policy.shell_policy == "deny":
                prompt += " Shell execution is denied by policy."
            else:
                prompt += (
                    " Shell execution is restricted to the exact commands in "
                    "allowedShellCommands."
                )
            contracts.append(
                DispatchContract(
                    adapter=self.name,
                    task_id=task.id,
                    worker=scheduled.worker,
                    prompt=prompt,
                    ownership=ownership,
                    required_capabilities=task.capabilities,
                    acceptance=task.acceptance,
                    transport=self.transport,
                    result_protocol=self.result_protocol,
                    workflow_id=graph.workflow_id,
                    execution_id=state.execution_id,
                    graph_digest=graph.digest,
                    route_digest=graph.route_digest or graph.digest,
                    execution_spec_digest=graph.execution_spec_digest or graph.digest,
                    attempt_id=run.attempt_id,
                    lease_generation=run.lease_generation,
                    fencing_token=run.fencing_token,
                    shell_policy=graph.policy.shell_policy,
                    allowed_shell_commands=graph.policy.allowed_shell_commands,
                )
            )
        return contracts

    def build_reserved(self, graph: TaskGraph, state: ExecutionState) -> list[DispatchContract]:
        """Rebuild contracts for a persisted reservation without changing its identity."""
        reserved = tuple(
            ScheduledTask(
                task_id=task_id,
                worker=run.assigned_worker or "",
                estimated_tokens=graph.task_map[task_id].estimated_tokens,
                critical_path_weight=0,
            )
            for task_id, run in state.tasks.items()
            if run.status == TaskStatus.RESERVED and not run.host_handle
        )
        if any(not item.worker for item in reserved):
            raise WorkflowError("reserved task is missing its assigned worker")
        decision = ScheduleDecision(
            workflow_id=graph.workflow_id,
            state_revision=state.revision,
            state_status=state.overall_status,
            worker_cap=graph.policy.max_workers,
            current_workers=len(reserved),
            desired_workers=len(reserved),
            scale_action="resume",
            tasks=reserved,
            deferred=(),
            budget_remaining=None,
        )
        return self.build(graph, decision, state)


class CodexAdapter(HostAdapter):
    name = "codex"
    transport = "codex-thread"
    capabilities = frozenset({"synchronous-dispatch", "receipt-v2"})


class ClaudeAdapter(HostAdapter):
    name = "claude"
    transport = "claude-agent-team"
    capabilities = frozenset({"synchronous-dispatch", "receipt-v2"})


_ADAPTERS: dict[str, type[HostAdapter]] = {
    "generic": HostAdapter,
    "codex": CodexAdapter,
    "claude": ClaudeAdapter,
}


def get_adapter(name: str) -> HostAdapter:
    try:
        return _ADAPTERS[name]()
    except KeyError as exc:
        raise WorkflowError(
            f"unknown adapter {name!r}; choose from {', '.join(sorted(_ADAPTERS))}"
        ) from exc


def host_status(evidence: Any | None = None, *, now: datetime | None = None) -> dict[str, str]:
    """Report runtime truth separately from adapter contract availability."""
    verified_adapters: set[str] = set()
    available_adapters = set(_ADAPTERS)
    if evidence is not None:
        if not isinstance(evidence, dict) or evidence.get("schemaVersion") != 1:
            raise WorkflowError("host evidence schemaVersion must be 1")
        available = evidence.get("availableAdapters")
        if not isinstance(available, list) or any(not isinstance(item, str) for item in available):
            raise WorkflowError("host evidence availableAdapters must be an array of adapter names")
        available_adapters = set(available)
        unknown_available = available_adapters - set(_ADAPTERS)
        if unknown_available:
            raise WorkflowError(f"unknown available adapters: {sorted(unknown_available)}")
        records = evidence.get("verified", [])
        if not isinstance(records, list):
            raise WorkflowError("host evidence verified must be an array")
        for index, record in enumerate(records):
            if not isinstance(record, dict):
                raise WorkflowError(f"verified[{index}] must be an object")
            adapter = record.get("adapter")
            receipt = record.get("receipt")
            proof = receipt.get("evidence") if isinstance(receipt, dict) else None
            observed = receipt.get("observedAt") if isinstance(receipt, dict) else None
            digest = record.get("receiptDigest")
            result = receipt.get("result") if isinstance(receipt, dict) else None
            if (
                not isinstance(adapter, str)
                or not adapter.strip()
                or not isinstance(receipt, dict)
                or receipt.get("schemaVersion") != 1
                or receipt.get("adapter") != adapter
                or not isinstance(proof, str)
                or not proof.strip()
                or not isinstance(observed, str)
                or not observed.strip()
                or not isinstance(digest, str)
                or not re.fullmatch(r"[0-9a-f]{64}", digest)
                or result != "PASS"
            ):
                raise WorkflowError(
                    f"verified[{index}] requires an identity-bound PASS receipt and digest"
                )
            canonical = json.dumps(receipt, sort_keys=True, separators=(",", ":"))
            if digest != hashlib.sha256(canonical.encode()).hexdigest():
                raise WorkflowError(f"verified[{index}].receiptDigest does not match receipt")
            try:
                observed_at = datetime.fromisoformat(observed.replace("Z", "+00:00")).astimezone(
                    UTC
                )
            except ValueError as exc:
                raise WorkflowError(
                    f"verified[{index}].observedAt must be a UTC timestamp"
                ) from exc
            current = now or datetime.now(UTC)
            if observed_at > current + timedelta(minutes=1) or current - observed_at > timedelta(
                minutes=15
            ):
                raise WorkflowError(f"verified[{index}] is stale or future-dated")
            if adapter not in available_adapters:
                raise WorkflowError(f"verified[{index}] adapter is not currently available")
            verified_adapters.add(adapter)
    unknown = verified_adapters - set(_ADAPTERS)
    if unknown:
        raise WorkflowError(f"unknown verified adapters: {sorted(unknown)}")
    return {
        name: (
            "UNAVAILABLE"
            if name not in available_adapters
            else "VERIFIED_RUNTIME"
            if name in verified_adapters
            else "CONTRACT_ONLY"
        )
        for name in sorted(_ADAPTERS)
    }
