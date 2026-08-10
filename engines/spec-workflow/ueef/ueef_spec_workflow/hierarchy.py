"""Bounded parent/subfeature hierarchy with independently verified roll-up."""

from __future__ import annotations

import hashlib
import hmac
import json
import re
from dataclasses import dataclass
from typing import Any

from .errors import WorkflowError


@dataclass(frozen=True)
class FeatureNode:
    feature_id: str
    children: tuple[str, ...]
    status: str
    verified: bool


_ID = re.compile(r"^[a-z0-9][a-z0-9-]{0,63}$")
_SHA256 = re.compile(r"^[0-9a-f]{64}$")
_VERIFICATION_FIELDS = frozenset(
    {
        "schemaVersion", "featureId", "workflowId", "graphDigest", "executionId",
        "status", "independent", "evidenceDigest", "diffDigest", "verifierId", "keyId",
        "receiptDigest", "signature",
    }
)


def _verified_receipt(
    item: dict[str, Any],
    feature_id: str,
    trusted_verifiers: dict[str, dict[str, bytes]],
    require_signatures: bool,
) -> bool:
    if "verified" in item:
        raise WorkflowError(
            "feature verified boolean is unsupported; use an identity-bound verification receipt"
        )
    receipt = item.get("verification")
    if receipt is None:
        return False
    if not isinstance(receipt, dict) or set(receipt) != _VERIFICATION_FIELDS:
        raise WorkflowError(f"{feature_id}.verification must be an exact schema-v2 receipt")
    workflow_id = item.get("workflowId")
    graph_digest = item.get("graphDigest")
    execution_id = item.get("executionId")
    if not isinstance(workflow_id, str) or not _ID.fullmatch(workflow_id):
        raise WorkflowError(f"{feature_id}.workflowId is invalid")
    if not isinstance(graph_digest, str) or not _SHA256.fullmatch(graph_digest):
        raise WorkflowError(f"{feature_id}.graphDigest must be a SHA-256 digest")
    if not isinstance(execution_id, str) or not _ID.fullmatch(execution_id):
        raise WorkflowError(f"{feature_id}.executionId is invalid")
    expected = {
        "schemaVersion": 2,
        "featureId": feature_id,
        "workflowId": workflow_id,
        "graphDigest": graph_digest,
        "executionId": execution_id,
        "status": "PASS",
        "independent": True,
    }
    for name, value in expected.items():
        if receipt.get(name) != value:
            raise WorkflowError(f"{feature_id}.verification.{name} identity mismatch")
    for name in ("evidenceDigest", "diffDigest", "receiptDigest", "signature"):
        if not isinstance(receipt.get(name), str) or not _SHA256.fullmatch(receipt[name]):
            raise WorkflowError(f"{feature_id}.verification.{name} must be a SHA-256 digest")
    verifier_id, key_id = receipt.get("verifierId"), receipt.get("keyId")
    if not isinstance(verifier_id, str) or not _ID.fullmatch(verifier_id):
        raise WorkflowError(f"{feature_id}.verification.verifierId is invalid")
    if not isinstance(key_id, str) or not _ID.fullmatch(key_id):
        raise WorkflowError(f"{feature_id}.verification.keyId is invalid")
    statement = {
        key: value for key, value in receipt.items() if key not in {"receiptDigest", "signature"}
    }
    actual = hashlib.sha256(
        json.dumps(statement, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()
    if receipt["receiptDigest"] != actual:
        raise WorkflowError(f"{feature_id}.verification.receiptDigest does not match the receipt")
    key = trusted_verifiers.get(verifier_id, {}).get(key_id)
    if key is None:
        if require_signatures:
            raise WorkflowError(f"{feature_id}.verification verifier key is not trusted")
        return True
    expected_signature = hmac.new(
        key,
        b"UEEF-HIERARCHY-VERIFICATION-V1\0" + actual.encode("ascii"),
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(receipt["signature"], expected_signature):
        raise WorkflowError(f"{feature_id}.verification signature is invalid")
    return True


def evaluate_hierarchy(
    document: Any,
    *,
    trusted_verifiers: dict[str, dict[str, bytes]] | None = None,
    require_signatures: bool = True,
) -> dict[str, Any]:
    if not isinstance(document, dict) or document.get("schemaVersion") != 1:
        raise WorkflowError("feature hierarchy schemaVersion must be 1")
    raw = document.get("features")
    if not isinstance(raw, list) or not raw or len(raw) > 200:
        raise WorkflowError("feature hierarchy requires 1-200 features")
    nodes: dict[str, FeatureNode] = {}
    for index, item in enumerate(raw):
        if not isinstance(item, dict):
            raise WorkflowError(f"features[{index}] must be an object")
        feature_id = item.get("id")
        children = item.get("children", [])
        status = item.get("status", "PENDING")
        verified = (
            _verified_receipt(
                item, feature_id, trusted_verifiers or {}, require_signatures
            )
            if isinstance(feature_id, str)
            else False
        )
        if not isinstance(feature_id, str) or not feature_id.strip() or len(feature_id) > 64:
            raise WorkflowError(f"features[{index}].id is invalid")
        if feature_id in nodes:
            raise WorkflowError("feature hierarchy contains duplicate IDs")
        if not isinstance(children, list) or any(not isinstance(child, str) for child in children):
            raise WorkflowError(f"features[{index}].children must be an array of IDs")
        if status not in {"PENDING", "RUNNING", "BLOCKED", "FAILED", "DONE"}:
            raise WorkflowError(f"features[{index}].status is invalid")
        nodes[feature_id] = FeatureNode(feature_id, tuple(children), status, verified)
    missing = sorted({child for node in nodes.values() for child in node.children} - set(nodes))
    if missing:
        raise WorkflowError(f"feature hierarchy references missing children: {missing}")
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(feature_id: str) -> None:
        if feature_id in visiting:
            raise WorkflowError("feature hierarchy contains a cycle")
        if feature_id in visited:
            return
        visiting.add(feature_id)
        for child in nodes[feature_id].children:
            visit(child)
        visiting.remove(feature_id)
        visited.add(feature_id)

    for feature_id in nodes:
        visit(feature_id)
    referenced = {child for node in nodes.values() for child in node.children}
    roots = sorted(set(nodes) - referenced)
    if not roots:
        raise WorkflowError("feature hierarchy requires at least one root")

    def rolled(feature_id: str) -> str:
        node = nodes[feature_id]
        child_states = [rolled(child) for child in node.children]
        if node.status == "FAILED" or "FAILED" in child_states:
            return "FAILED"
        if node.status == "BLOCKED" or "BLOCKED" in child_states:
            return "BLOCKED"
        if (
            node.status == "DONE"
            and node.verified
            and all(state == "DONE" for state in child_states)
        ):
            return "DONE"
        if node.status == "RUNNING" or any(state == "RUNNING" for state in child_states):
            return "RUNNING"
        return "PENDING"

    statuses = {feature_id: rolled(feature_id) for feature_id in sorted(nodes)}
    return {"schemaVersion": 1, "roots": roots, "statuses": statuses}
