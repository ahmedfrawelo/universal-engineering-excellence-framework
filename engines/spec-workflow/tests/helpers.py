from __future__ import annotations

from typing import Any

from ueef_spec_workflow.model import TaskGraph


def graph_data(*tasks: dict[str, Any], **policy: Any) -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "workflowId": "demo-flow",
        "policy": {
            "tier": policy.get("tier", "T3"),
            "maxWorkers": policy.get("maxWorkers", 4),
            "tokenBudgetMode": policy.get("tokenBudgetMode", "bounded"),
            "tokenBudget": policy.get("tokenBudget", 20000),
            "retryLimit": policy.get("retryLimit", 1),
            "shellPolicy": "deny",
            "allowedShellCommands": [],
        },
        "tasks": list(tasks),
    }


def task(task_id: str, **values: Any) -> dict[str, Any]:
    return {
        "id": task_id,
        "title": values.get("title", task_id),
        "dependsOn": values.get("dependsOn", []),
        "requirements": values.get("requirements", ["REQ-001"]),
        "acceptance": values.get("acceptance", ["AC-001"]),
        "writeSet": values.get("writeSet", [f"src/{task_id.lower()}"]),
        "forbiddenPaths": values.get("forbiddenPaths", []),
        "capabilities": values.get("capabilities", []),
        "effortPoints": values.get("effortPoints", 1),
        "risk": values.get("risk", 0),
        "priority": values.get("priority", 0),
        "parallelSafe": values.get("parallelSafe", True),
        "readOnly": values.get("readOnly", False),
        **({"retryLimit": values["retryLimit"]} if "retryLimit" in values else {}),
    }


def graph(*tasks: dict[str, Any], **policy: Any) -> TaskGraph:
    return TaskGraph.from_dict(graph_data(*tasks, **policy))
