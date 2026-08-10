"""Bounded multi-feature portfolio DAG orchestration with verified roll-up."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any

from .errors import WorkflowError

_ID = re.compile(r"^[a-z0-9][a-z0-9-]{0,62}$")
_SHA256 = re.compile(r"^[0-9a-f]{64}$")
_OBSERVED = frozenset({"PENDING", "RUNNING", "DONE", "FAILED", "CANCELLED"})
_VERIFICATION = frozenset({"PENDING", "PASS", "FAIL"})
_MAX_FEATURES = 200


@dataclass(frozen=True)
class PortfolioFeature:
    feature_id: str
    workflow_id: str
    graph_digest: str
    execution_id: str
    depends_on: tuple[str, ...]
    required: bool


def orchestrate_portfolio(document: Any, observed: Any) -> dict[str, Any]:
    if not isinstance(document, dict) or document.get("schemaVersion") != 2:
        raise WorkflowError("portfolio schemaVersion must be 2")
    raw_features, max_concurrency = document.get("features"), document.get("maxConcurrency")
    if not isinstance(raw_features, list) or not 1 <= len(raw_features) <= _MAX_FEATURES:
        raise WorkflowError(f"portfolio requires 1-{_MAX_FEATURES} features")
    if (
        isinstance(max_concurrency, bool)
        or not isinstance(max_concurrency, int)
        or not 1 <= max_concurrency <= 16
    ):
        raise WorkflowError("portfolio maxConcurrency must be an integer from 1 through 16")
    features: dict[str, PortfolioFeature] = {}
    for index, raw in enumerate(raw_features):
        if not isinstance(raw, dict):
            raise WorkflowError(f"features[{index}] must be an object")
        feature_id, workflow_id = raw.get("id"), raw.get("workflowId")
        graph_digest, execution_id = raw.get("graphDigest"), raw.get("executionId")
        dependencies, required = raw.get("dependsOn", []), raw.get("required", True)
        if not isinstance(feature_id, str) or not _ID.fullmatch(feature_id):
            raise WorkflowError(f"features[{index}].id is invalid")
        if feature_id in features:
            raise WorkflowError("portfolio feature IDs must be unique")
        if not isinstance(workflow_id, str) or not _ID.fullmatch(workflow_id):
            raise WorkflowError(f"{feature_id}.workflowId is invalid")
        if not isinstance(graph_digest, str) or not _SHA256.fullmatch(graph_digest):
            raise WorkflowError(f"{feature_id}.graphDigest must be a SHA-256 digest")
        if not isinstance(execution_id, str) or not _ID.fullmatch(execution_id):
            raise WorkflowError(f"{feature_id}.executionId is invalid")
        if (
            not isinstance(dependencies, list)
            or len(dependencies) > _MAX_FEATURES
            or any(not isinstance(item, str) or not _ID.fullmatch(item) for item in dependencies)
            or len(set(dependencies)) != len(dependencies)
        ):
            raise WorkflowError(f"{feature_id}.dependsOn must contain unique valid IDs")
        if feature_id in dependencies:
            raise WorkflowError(f"{feature_id} cannot depend on itself")
        if not isinstance(required, bool):
            raise WorkflowError(f"{feature_id}.required must be boolean")
        features[feature_id] = PortfolioFeature(
            feature_id, workflow_id, graph_digest, execution_id, tuple(dependencies), required
        )
    missing = sorted(
        {dep for feature in features.values() for dep in feature.depends_on} - features.keys()
    )
    if missing:
        raise WorkflowError(f"portfolio references missing dependencies: {missing}")
    visiting: list[str] = []
    visited: set[str] = set()

    def visit(feature_id: str) -> None:
        if feature_id in visiting:
            cycle = visiting[visiting.index(feature_id) :] + [feature_id]
            raise WorkflowError(f"portfolio contains a cycle: {' -> '.join(cycle)}")
        if feature_id in visited:
            return
        visiting.append(feature_id)
        for dependency in features[feature_id].depends_on:
            visit(dependency)
        visiting.pop()
        visited.add(feature_id)

    for feature_id in features:
        visit(feature_id)
    if not isinstance(observed, dict) or set(observed) - features.keys():
        raise WorkflowError("observed portfolio state must reference known features only")
    effective: dict[str, str] = {}
    for feature_id, feature in features.items():
        record = observed.get(feature_id)
        if record is None:
            effective[feature_id] = "PENDING"
            continue
        if not isinstance(record, dict):
            raise WorkflowError(f"observed {feature_id} must be an identity-bound object")
        for name, expected in {
            "workflowId": feature.workflow_id,
            "graphDigest": feature.graph_digest,
            "executionId": feature.execution_id,
        }.items():
            if record.get(name) != expected:
                raise WorkflowError(f"observed {feature_id}.{name} identity mismatch")
        status, verification = record.get("status"), record.get("verificationStatus")
        if status not in _OBSERVED or verification not in _VERIFICATION:
            raise WorkflowError(f"observed {feature_id} status or verificationStatus is invalid")
        effective[feature_id] = (
            "UNVERIFIED" if status == "DONE" and verification != "PASS" else status
        )
    blocked_by: dict[str, list[str]] = {}
    candidates: list[str] = []
    for feature_id, feature in features.items():
        blockers = sorted(
            dependency
            for dependency in feature.depends_on
            if effective[dependency] in {"FAILED", "CANCELLED", "UNVERIFIED"}
        )
        blocked_by[feature_id] = blockers
        if (
            effective[feature_id] == "PENDING"
            and not blockers
            and all(effective[dependency] == "DONE" for dependency in feature.depends_on)
        ):
            candidates.append(feature_id)
    running = sum(status == "RUNNING" for status in effective.values())
    slots = max(0, max_concurrency - running)
    ready = sorted(candidates)[:slots]
    deferred = sorted(candidates)[slots:]
    required = [feature_id for feature_id, feature in features.items() if feature.required]
    if any(effective[item] == "FAILED" for item in required):
        overall = "FAILED"
    elif any(effective[item] == "CANCELLED" for item in required):
        overall = "CANCELLED"
    elif all(effective[item] == "DONE" for item in required):
        overall = "DONE"
    elif any(effective[item] == "RUNNING" for item in features):
        overall = "RUNNING"
    elif ready:
        overall = "READY"
    else:
        overall = "BLOCKED"
    return {
        "schemaVersion": 2,
        "status": overall,
        "ready": ready,
        "deferred": deferred,
        "blockedBy": {key: value for key, value in sorted(blocked_by.items()) if value},
        "statuses": dict(sorted(effective.items())),
    }
