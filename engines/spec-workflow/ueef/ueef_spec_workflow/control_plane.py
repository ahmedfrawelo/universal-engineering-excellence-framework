"""Truthful control-plane status aggregation across execution safety domains."""

from __future__ import annotations

from collections.abc import Iterable, Mapping
from typing import Any

from .errors import WorkflowError
from .model import TaskGraph
from .state import ExecutionState

_APPROVAL_BLOCKS = frozenset(
    {"DENIED", "EXPIRED", "IDENTITY_CHANGED", "REVOKED", "SCOPE_CHANGED"}
)
_APPROVAL_WAITS = frozenset({"NOT_CONFIGURED", "PENDING"})
_SUPPLY_STATUSES = frozenset({"PASS", "DEGRADED", "FAILED", "VERIFYING", "NOT_CHECKED"})


def _host_status(value: str | Mapping[str, str], required_host: str) -> str:
    if isinstance(value, str):
        status = value
    elif isinstance(value, Mapping):
        status = value.get(required_host)
    else:
        status = None
    if not isinstance(status, str) or not status:
        raise WorkflowError(f"host status is missing required host {required_host!r}")
    return status


def _supply_status(value: Mapping[str, Any] | None) -> str:
    if value is None:
        return "NOT_CHECKED"
    status = value.get("status")
    if status == "FAIL":
        status = "FAILED"
    if status is None and isinstance(value.get("verified"), bool):
        status = "PASS" if value["verified"] else "FAILED"
    if status not in _SUPPLY_STATUSES:
        raise WorkflowError("supply-chain result has an invalid or missing status")
    return status


def aggregate_control_status(
    graph: TaskGraph,
    state: ExecutionState,
    host_status: str | Mapping[str, str],
    approval_statuses: Iterable[Mapping[str, Any]],
    *,
    portfolio_result: Mapping[str, Any] | None = None,
    supply_chain_result: Mapping[str, Any] | None = None,
    required_host: str = "codex",
) -> dict[str, Any]:
    """Return one priority status plus every uncollapsed contributing status."""

    if state.workflow_id != graph.workflow_id or state.graph_digest != graph.digest:
        raise WorkflowError("control-plane state identity does not match the task graph")
    runtime = _host_status(host_status, required_host)
    approvals = [dict(item) for item in approval_statuses]
    if any(not isinstance(item.get("status"), str) for item in approvals):
        raise WorkflowError("approval statuses must contain a string status")
    approval_values = [item["status"] for item in approvals]
    portfolio_status = "NOT_CONFIGURED"
    portfolio_components: dict[str, Any] = {}
    if portfolio_result is not None:
        portfolio_status = portfolio_result.get("status")
        if not isinstance(portfolio_status, str):
            raise WorkflowError("portfolio result must contain a string status")
        portfolio_components = dict(portfolio_result)
    supply_status = _supply_status(supply_chain_result)
    workflow_status = state.overall_status

    hard_failure = (
        workflow_status in {"FAILED", "NEEDS_REPLAN"}
        or portfolio_status in {"FAILED", "CANCELLED"}
        or supply_status == "FAILED"
    )
    approval_blocked = any(status in _APPROVAL_BLOCKS for status in approval_values)
    blocked = workflow_status == "BLOCKED" or portfolio_status == "BLOCKED" or approval_blocked
    waiting = any(status in _APPROVAL_WAITS for status in approval_values)
    active = workflow_status not in {"DONE", "FAILED", "NEEDS_REPLAN"}
    unavailable = active and runtime != "VERIFIED_RUNTIME"
    verifying = (
        workflow_status == "VERIFYING"
        or portfolio_status == "VERIFYING"
        or supply_status == "VERIFYING"
        or "UNVERIFIED" in portfolio_components.get("statuses", {}).values()
    )
    degraded = supply_status == "DEGRADED" or portfolio_status == "DEGRADED"
    portfolio_states = portfolio_components.get("statuses", {})
    if isinstance(portfolio_states, Mapping) and any(
        status in {"FAILED", "CANCELLED", "UNVERIFIED"}
        for status in portfolio_states.values()
    ) and portfolio_status not in {"FAILED", "CANCELLED"}:
        degraded = True

    if hard_failure:
        status = "FAILED"
    elif blocked:
        status = "BLOCKED"
    elif waiting:
        status = "WAITING_APPROVAL"
    elif unavailable:
        status = "UNAVAILABLE"
    elif verifying:
        status = "VERIFYING"
    elif degraded:
        status = "DEGRADED"
    elif workflow_status == "DONE" and portfolio_status in {"DONE", "NOT_CONFIGURED"}:
        status = "DONE"
    else:
        status = workflow_status
    return {
        "schemaVersion": 1,
        "status": status,
        "workflowStatus": workflow_status,
        "hostStatus": runtime,
        "approvalStatuses": approval_values,
        "portfolioStatus": portfolio_status,
        "supplyChainStatus": supply_status,
        "workflowId": graph.workflow_id,
        "graphDigest": graph.digest,
        "executionId": state.execution_id,
        "signals": {
            "failed": hard_failure,
            "blocked": blocked,
            "waitingApproval": waiting,
            "unavailable": unavailable,
            "verifying": verifying,
            "degraded": degraded,
        },
    }
