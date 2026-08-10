"""Durable, identity-bound human approval gates with tamper-evident audit history."""

from __future__ import annotations

import hashlib
import hmac
import json
import os
import re
import tempfile
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from .errors import WorkflowError
from .state import _exclusive_file_lock

_IDENTIFIER = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:@/-]{0,127}$")
_SHA256 = re.compile(r"^[0-9a-f]{64}$")
_MAX_GATES = 100
_MAX_EVENTS = 10_000
_MAX_BYTES = 10 * 1024 * 1024
_BINDING_FIELDS = ("workflowId", "graphDigest", "executionId", "taskId", "artifactDigest")
_SIGNATURE_DOMAIN = "ueef-approval-event-v1"


def _trusted_key(
    trusted_keys: dict[str, dict[str, bytes]], identity: object, key_id: object
) -> bytes:
    if not isinstance(identity, str) or not isinstance(key_id, str):
        raise WorkflowError("approval signature identity and keyId are required")
    key = trusted_keys.get(identity, {}).get(key_id)
    if not isinstance(key, bytes) or len(key) < 32:
        raise WorkflowError("approval signature key is not trusted for this identity")
    return key


def _signature_payload(event: dict[str, Any]) -> bytes:
    payload = {
        key: value
        for key, value in event.items()
        if key not in {"eventDigest", "signature"}
    }
    return json.dumps(
        {"domain": _SIGNATURE_DOMAIN, "event": payload},
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def task_approval_binding(graph: Any, state: Any, task_id: str) -> dict[str, str]:
    """Build the stable identity a human approval authorizes for one graph task."""

    try:
        task = graph.task_map[task_id]
    except KeyError as exc:
        raise WorkflowError(f"unknown approval task: {task_id}") from exc
    artifact_digest = hashlib.sha256(
        json.dumps(task.to_dict(), sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()
    return {
        "workflowId": graph.workflow_id,
        "graphDigest": graph.digest,
        "executionId": state.execution_id,
        "taskId": task_id,
        "artifactDigest": artifact_digest,
    }


def approval_status_for_task(
    ledger: ApprovalLedger, graph: Any, state: Any, task_id: str, *, now: datetime
) -> dict[str, Any]:
    """Return the matching gate status, rejecting ambiguous duplicate gates."""

    binding = task_approval_binding(graph, state, task_id)
    matches = [gate for gate in ledger.gates.values() if gate.binding == binding]
    if len(matches) > 1:
        raise WorkflowError(f"multiple approval gates match task {task_id}")
    if not matches:
        return {"status": "NOT_CONFIGURED", "taskId": task_id, "binding": binding}
    gate = matches[0]
    return {
        "gateId": gate.gate_id,
        "taskId": task_id,
        **ledger.status(gate.gate_id, now=now, binding=binding),
    }


def _utc(value: str, field_name: str) -> datetime:
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (TypeError, ValueError) as exc:
        raise WorkflowError(f"{field_name} must be an ISO-8601 timestamp") from exc
    if parsed.tzinfo is None:
        raise WorkflowError(f"{field_name} must include a timezone")
    return parsed.astimezone(UTC)


def _timestamp(value: datetime) -> str:
    if value.tzinfo is None:
        raise WorkflowError("approval event time must include a timezone")
    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


def _digest(payload: dict[str, Any]) -> str:
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def _binding(raw: dict[str, Any], owner: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for name in _BINDING_FIELDS:
        value = raw.get(name)
        if not isinstance(value, str):
            raise WorkflowError(f"{owner}.{name} is required")
        pattern = _SHA256 if name in {"graphDigest", "artifactDigest"} else _IDENTIFIER
        if not pattern.fullmatch(value):
            raise WorkflowError(f"{owner}.{name} is invalid")
        result[name] = value
    return result


@dataclass(frozen=True)
class ApprovalGate:
    gate_id: str
    binding: dict[str, str]
    approvers: dict[str, str]
    threshold: int
    expires_at: str


@dataclass
class ApprovalLedger:
    """Append-only approval state that survives controller restarts."""

    gates: dict[str, ApprovalGate]
    events: list[dict[str, Any]] = field(default_factory=list)
    trusted_keys: dict[str, dict[str, bytes]] = field(default_factory=dict, repr=False)
    require_signatures: bool = False

    @classmethod
    def from_dict(
        cls,
        document: Any,
        *,
        trusted_keys: dict[str, dict[str, bytes]] | None = None,
        require_signatures: bool | None = None,
    ) -> ApprovalLedger:
        if not isinstance(document, dict) or document.get("schemaVersion") != 2:
            raise WorkflowError("approval ledger schemaVersion must be 2")
        raw_gates = document.get("gates")
        raw_events = document.get("events", [])
        if not isinstance(raw_gates, list) or not 1 <= len(raw_gates) <= _MAX_GATES:
            raise WorkflowError(f"approval ledger requires 1-{_MAX_GATES} gates")
        if not isinstance(raw_events, list) or len(raw_events) > _MAX_EVENTS:
            raise WorkflowError(f"approval ledger cannot exceed {_MAX_EVENTS} events")
        gates: dict[str, ApprovalGate] = {}
        for index, raw in enumerate(raw_gates):
            if not isinstance(raw, dict):
                raise WorkflowError(f"gates[{index}] must be an object")
            gate_id = raw.get("id")
            if not isinstance(gate_id, str) or not _IDENTIFIER.fullmatch(gate_id):
                raise WorkflowError(f"gates[{index}].id is invalid")
            if gate_id in gates:
                raise WorkflowError("approval gate IDs must be unique")
            approvers_raw = raw.get("approvers")
            if not isinstance(approvers_raw, list) or not approvers_raw:
                raise WorkflowError(f"{gate_id}.approvers must be a non-empty array")
            approvers: dict[str, str] = {}
            for approver in approvers_raw:
                if not isinstance(approver, dict):
                    raise WorkflowError(f"{gate_id}.approvers entries must be objects")
                identity, role = approver.get("identity"), approver.get("role")
                if (
                    not isinstance(identity, str)
                    or not _IDENTIFIER.fullmatch(identity)
                    or not isinstance(role, str)
                    or not _IDENTIFIER.fullmatch(role)
                    or identity in approvers
                ):
                    raise WorkflowError(f"{gate_id}.approvers contains an invalid identity/role")
                approvers[identity] = role
            threshold = raw.get("threshold", 1)
            if (
                isinstance(threshold, bool)
                or not isinstance(threshold, int)
                or not 1 <= threshold <= len(approvers)
            ):
                raise WorkflowError(f"{gate_id}.threshold is invalid")
            expires_at = raw.get("expiresAt")
            if not isinstance(expires_at, str):
                raise WorkflowError(f"{gate_id}.expiresAt is required")
            _utc(expires_at, f"{gate_id}.expiresAt")
            gates[gate_id] = ApprovalGate(
                gate_id, _binding(raw, gate_id), approvers, threshold, expires_at
            )
        keyring = trusted_keys or {}
        ledger = cls(
            gates=gates,
            trusted_keys=keyring,
            require_signatures=bool(keyring) if require_signatures is None else require_signatures,
        )
        for event in raw_events:
            ledger._load_event(event)
        return ledger

    def _load_event(self, event: Any) -> None:
        if not isinstance(event, dict):
            raise WorkflowError("approval events must be objects")
        expected_sequence = len(self.events) + 1
        if event.get("sequence") != expected_sequence:
            raise WorkflowError("approval event sequence is not monotonic")
        expected_previous = self.events[-1]["eventDigest"] if self.events else "0" * 64
        payload = {key: value for key, value in event.items() if key != "eventDigest"}
        if payload.get("previousDigest") != expected_previous:
            raise WorkflowError("approval audit chain is broken")
        digest = event.get("eventDigest")
        if not isinstance(digest, str) or digest != _digest(payload):
            raise WorkflowError("approval event digest does not match its payload")
        occurred = self._validate_event(payload)
        self._verify_signature(event)
        if self.events and occurred <= _utc(self.events[-1]["occurredAt"], "occurredAt"):
            raise WorkflowError("approval event time is retrograde")
        self.events.append(dict(event))

    def _verify_signature(self, event: dict[str, Any]) -> None:
        signature = event.get("signature")
        if signature is None and not self.require_signatures:
            return
        if not isinstance(signature, dict):
            raise WorkflowError("approval event requires a trusted signature")
        if signature.get("algorithm") != "hmac-sha256":
            raise WorkflowError("approval signature algorithm is unsupported")
        key = _trusted_key(self.trusted_keys, event.get("identity"), signature.get("keyId"))
        value = signature.get("value")
        if not isinstance(value, str) or not _SHA256.fullmatch(value):
            raise WorkflowError("approval signature value is invalid")
        expected = hmac.new(key, _signature_payload(event), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(value, expected):
            raise WorkflowError("approval event signature verification failed")

    def _validate_event(self, event: dict[str, Any]) -> datetime:
        gate_id, identity = event.get("gateId"), event.get("identity")
        if gate_id not in self.gates:
            raise WorkflowError("approval event references an unknown gate")
        gate = self.gates[gate_id]
        if identity not in gate.approvers:
            raise WorkflowError("approval identity is not authorized for the gate")
        if event.get("approverRole") != gate.approvers[identity]:
            raise WorkflowError("approval approverRole does not match the authorized identity")
        if event.get("action") not in {"GRANT", "REVOKE"}:
            raise WorkflowError("approval event action must be GRANT or REVOKE")
        for name, expected in gate.binding.items():
            if event.get(name) != expected:
                raise WorkflowError(f"approval event {name} does not match the gate")
        evidence = event.get("evidenceDigest")
        if not isinstance(evidence, str) or not _SHA256.fullmatch(evidence):
            raise WorkflowError("approval event evidenceDigest must be a SHA-256 digest")
        occurred_at = event.get("occurredAt")
        if not isinstance(occurred_at, str):
            raise WorkflowError("approval event occurredAt must be an ISO-8601 timestamp")
        occurred = _utc(occurred_at, "approval event occurredAt")
        if occurred >= _utc(gate.expires_at, f"{gate_id}.expiresAt"):
            raise WorkflowError("approval event occurs at or after gate expiry")
        return occurred

    def record(
        self,
        gate_id: str,
        identity: str,
        approver_role: str,
        action: str,
        evidence_digest: str,
        binding: dict[str, str],
        *,
        now: datetime,
        occurred_at: datetime | None = None,
        signing_key: bytes | None = None,
        key_id: str | None = None,
    ) -> dict[str, Any]:
        occurred = now if occurred_at is None else occurred_at
        if occurred.astimezone(UTC) > now.astimezone(UTC):
            raise WorkflowError("approval event time cannot be in the future")
        if self.events and occurred.astimezone(UTC) <= _utc(
            self.events[-1]["occurredAt"], "occurredAt"
        ):
            raise WorkflowError("approval event time is retrograde")
        event: dict[str, Any] = {
            "sequence": len(self.events) + 1,
            "gateId": gate_id,
            "identity": identity,
            "approverRole": approver_role,
            "action": action,
            **binding,
            "evidenceDigest": evidence_digest,
            "occurredAt": _timestamp(occurred),
            "previousDigest": self.events[-1]["eventDigest"] if self.events else "0" * 64,
        }
        self._validate_event(event)
        if signing_key is not None:
            if not isinstance(key_id, str) or not _IDENTIFIER.fullmatch(key_id):
                raise WorkflowError("approval signing keyId is invalid")
            trusted = _trusted_key(self.trusted_keys, identity, key_id)
            if not hmac.compare_digest(signing_key, trusted):
                raise WorkflowError("approval signing key does not match the trusted keyring")
            event["signature"] = {
                "algorithm": "hmac-sha256",
                "keyId": key_id,
                "value": hmac.new(
                    signing_key, _signature_payload(event), hashlib.sha256
                ).hexdigest(),
            }
        self._verify_signature(event)
        event["eventDigest"] = _digest(event)
        self.events.append(event)
        return dict(event)

    def status(self, gate_id: str, *, now: datetime, binding: dict[str, str]) -> dict[str, Any]:
        gate = self.gates.get(gate_id)
        if gate is None:
            raise WorkflowError("unknown approval gate")
        if binding != gate.binding:
            return {"status": "IDENTITY_CHANGED", "approvedBy": [], "required": gate.threshold}
        if now.astimezone(UTC) >= _utc(gate.expires_at, f"{gate_id}.expiresAt"):
            return {"status": "EXPIRED", "approvedBy": [], "required": gate.threshold}
        current: dict[str, bool] = {}
        for event in self.events:
            if event["gateId"] == gate_id:
                current[event["identity"]] = event["action"] == "GRANT"
        approved = sorted(identity for identity, active in current.items() if active)
        return {
            "status": "APPROVED" if len(approved) >= gate.threshold else "PENDING",
            "approvedBy": approved,
            "required": gate.threshold,
        }

    def to_dict(self) -> dict[str, Any]:
        return {
            "schemaVersion": 2,
            "gates": [
                {
                    "id": gate.gate_id,
                    **gate.binding,
                    "approvers": [
                        {"identity": identity, "role": role}
                        for identity, role in gate.approvers.items()
                    ],
                    "threshold": gate.threshold,
                    "expiresAt": gate.expires_at,
                }
                for gate in self.gates.values()
            ],
            "events": [dict(event) for event in self.events],
        }


class ApprovalStore:
    """Atomic, lock-protected and fsync-backed approval persistence."""

    def __init__(
        self,
        path: str | Path,
        *,
        trusted_keys: dict[str, dict[str, bytes]] | None = None,
        require_signatures: bool | None = None,
    ) -> None:
        self.path = Path(path)
        self.lock_path = self.path.with_name(self.path.name + ".lock")
        self.trusted_keys = trusted_keys or {}
        self.require_signatures = (
            bool(self.trusted_keys) if require_signatures is None else require_signatures
        )

    def _load_unlocked(self) -> ApprovalLedger:
        try:
            if self.path.stat().st_size > _MAX_BYTES:
                raise WorkflowError("approval ledger exceeds its size limit")
            return ApprovalLedger.from_dict(
                json.loads(self.path.read_text(encoding="utf-8")),
                trusted_keys=self.trusted_keys,
                require_signatures=self.require_signatures,
            )
        except FileNotFoundError as exc:
            raise WorkflowError(f"approval ledger does not exist: {self.path}") from exc
        except json.JSONDecodeError as exc:
            raise WorkflowError(f"invalid approval ledger JSON: {exc}") from exc

    def load(self) -> ApprovalLedger:
        with _exclusive_file_lock(self.lock_path):
            return self._load_unlocked()

    def _save_unlocked(self, ledger: ApprovalLedger) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        payload = json.dumps(ledger.to_dict(), ensure_ascii=False, indent=2) + "\n"
        descriptor, temporary_name = tempfile.mkstemp(
            prefix=self.path.name + ".", suffix=".tmp", dir=self.path.parent
        )
        try:
            with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as handle:
                handle.write(payload)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary_name, self.path)
            if os.name != "nt":
                directory = os.open(self.path.parent, os.O_RDONLY)
                try:
                    os.fsync(directory)
                finally:
                    os.close(directory)
        except BaseException:
            try:
                os.unlink(temporary_name)
            except FileNotFoundError:
                pass
            raise

    def save(self, ledger: ApprovalLedger) -> None:
        with _exclusive_file_lock(self.lock_path):
            self._save_unlocked(ledger)

    def record(self, *args: Any, **kwargs: Any) -> dict[str, Any]:
        """Atomically reload, append one validated event, and persist it."""

        with _exclusive_file_lock(self.lock_path):
            ledger = self._load_unlocked()
            event = ledger.record(*args, **kwargs)
            self._save_unlocked(ledger)
            return event
