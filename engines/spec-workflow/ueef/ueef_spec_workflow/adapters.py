"""Host-neutral dispatch contracts for scheduled tasks."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from .errors import WorkflowError
from .model import TaskGraph
from .scheduler import ScheduleDecision


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
        }


class HostAdapter:
    name = "generic"
    transport = "external"
    result_protocol = "ueef-host-result/v1"

    def build(self, graph: TaskGraph, decision: ScheduleDecision) -> list[DispatchContract]:
        task_map = graph.task_map
        contracts: list[DispatchContract] = []
        for scheduled in decision.tasks:
            task = task_map[scheduled.task_id]
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
                )
            )
        return contracts


class CodexAdapter(HostAdapter):
    name = "codex"
    transport = "codex-thread"


class ClaudeAdapter(HostAdapter):
    name = "claude"
    transport = "claude-agent-team"


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
