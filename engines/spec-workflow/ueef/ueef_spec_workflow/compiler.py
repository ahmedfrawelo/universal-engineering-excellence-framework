"""Deterministically compile the canonical Markdown plan into an executable graph."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from typing import Any

from .errors import WorkflowError
from .model import TaskGraph

_TASK = re.compile(r"^- \[[ xX]\] (TASK-[A-Z0-9_-]+)\s+(.+?)\s*$")
_FIELD = re.compile(r"^  - ([A-Za-z ]+):\s*(.*?)\s*$")
_REQUIRED_FIELDS = frozenset(
    {
        "requirements",
        "acceptance",
        "delegation",
        "allowed write set",
        "forbidden paths",
        "depends on",
        "capabilities",
        "effort points",
        "risk",
        "priority",
        "parallel safe",
        "read only",
        "evidence",
        "done when",
    }
)
_DIGEST = re.compile(r"^[0-9a-f]{64}$")


def _json_digest(value: Any) -> str:
    payload = json.dumps(
        value, ensure_ascii=False, separators=(",", ":"), allow_nan=False
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def _list(value: str) -> list[str]:
    if value.strip().casefold() in {"", "none"}:
        return []
    return [item.strip() for item in value.split(",") if item.strip()]


def _integer(value: str, field: str) -> int:
    try:
        return int(value)
    except ValueError as exc:
        raise WorkflowError(f"{field} must be an integer") from exc


def _boolean(value: str, field: str) -> bool:
    normalized = value.casefold()
    if normalized not in {"true", "false"}:
        raise WorkflowError(f"{field} must be true or false")
    return normalized == "true"


def _acceptance_evidence(value: str, acceptance: list[str], task_id: str) -> str:
    """Validate and canonicalize the per-criterion evidence contract."""

    try:
        parsed = json.loads(value)
    except json.JSONDecodeError as exc:
        raise WorkflowError(
            f"{task_id}.evidence must be a JSON object keyed by acceptance identifiers"
        ) from exc
    if not isinstance(parsed, dict) or any(
        not isinstance(key, str) or not isinstance(item, str) or not item.strip()
        for key, item in parsed.items()
    ):
        raise WorkflowError(
            f"{task_id}.evidence must map acceptance identifiers to non-empty strings"
        )
    expected = set(acceptance)
    actual = set(parsed)
    if actual != expected:
        raise WorkflowError(
            f"{task_id}.evidence acceptance binding mismatch: "
            f"missing={sorted(expected - actual)}, unknown={sorted(actual - expected)}"
        )
    return json.dumps(
        {key: parsed[key].strip() for key in sorted(parsed)},
        ensure_ascii=False,
        separators=(",", ":"),
    )


def parse_tasks(markdown: str) -> list[dict[str, Any]]:
    """Parse the intentionally narrow UEEF task-plan Markdown contract."""

    tasks: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    fields: dict[str, str] = {}

    def finish() -> None:
        nonlocal current, fields
        if current is None:
            return
        missing = sorted(_REQUIRED_FIELDS - fields.keys())
        if missing:
            raise WorkflowError(f"{current['id']} missing fields: {', '.join(missing)}")
        read_only = _boolean(fields["read only"], f"{current['id']}.readOnly")
        acceptance = _list(fields["acceptance"])
        task = {
            **current,
            "dependsOn": _list(fields["depends on"]),
            "requirements": _list(fields["requirements"]),
            "acceptance": acceptance,
            "writeSet": _list(fields["allowed write set"]),
            "forbiddenPaths": _list(fields["forbidden paths"]),
            "capabilities": _list(fields["capabilities"]),
            "effortPoints": _integer(fields["effort points"], f"{current['id']}.effortPoints"),
            "risk": _integer(fields["risk"], f"{current['id']}.risk"),
            "priority": _integer(fields["priority"], f"{current['id']}.priority"),
            "parallelSafe": _boolean(fields["parallel safe"], f"{current['id']}.parallelSafe"),
            "readOnly": read_only,
            "sourceEvidence": _acceptance_evidence(
                fields["evidence"], acceptance, current["id"]
            ),
        }
        tasks.append(task)
        current, fields = None, {}

    for line in markdown.splitlines():
        task_match = _TASK.match(line)
        if task_match:
            finish()
            current = {"id": task_match.group(1), "title": task_match.group(2).strip()}
            continue
        field_match = _FIELD.match(line)
        if current is not None and field_match:
            name = field_match.group(1).strip().casefold()
            if name in fields:
                raise WorkflowError(f"{current['id']} duplicates field {name!r}")
            fields[name] = field_match.group(2).strip()
    finish()
    if not tasks:
        raise WorkflowError("tasks Markdown does not declare any TASK entries")
    return tasks


def _route_values(route: Any) -> tuple[str, int, str, str, str]:
    if not isinstance(route, dict) or route.get("schemaVersion") != 3:
        raise WorkflowError("route must be a schema-version-3 object")
    economy = route.get("tokenEconomy")
    if not isinstance(economy, dict):
        raise WorkflowError("route.tokenEconomy must be an object")
    tier = route.get("tier")
    workers = economy.get("maxWorkerCount")
    mode = economy.get("budgetMode")
    route_digest = route.get("routeDigest")
    execution = route.get("executionSpec")
    if not isinstance(execution, dict):
        raise WorkflowError("route.executionSpec must be an object")
    execution_digest = execution.get("digest")
    if not isinstance(tier, str):
        raise WorkflowError("route.tier must be a string")
    if isinstance(workers, bool) or not isinstance(workers, int) or workers < 1:
        raise WorkflowError("route maxWorkerCount must be a positive integer")
    if mode not in {"minimal", "bounded", "expanded"}:
        raise WorkflowError("route budgetMode is invalid")
    if not isinstance(route_digest, str) or not _DIGEST.fullmatch(route_digest):
        raise WorkflowError("route.routeDigest must be a lowercase SHA-256 digest")
    if not isinstance(execution_digest, str) or not _DIGEST.fullmatch(execution_digest):
        raise WorkflowError("route.executionSpec.digest must be a lowercase SHA-256 digest")
    execution_payload = {key: value for key, value in execution.items() if key != "digest"}
    if _json_digest(execution_payload) != execution_digest:
        raise WorkflowError("route.executionSpec.digest does not match its canonical content")
    route_identity = {
        "tier": route.get("tier"),
        "workUnitId": route.get("workUnitId"),
        "invocationIndex": route.get("invocationIndex"),
        "preferredModel": route.get("preferredModel"),
        "hostReasoning": route.get("hostReasoning"),
        "fallbackModel": route.get("fallbackModel"),
        "fallbackHostReasoning": route.get("fallbackHostReasoning"),
        "tokenEconomy": route.get("tokenEconomy"),
        "decision": route.get("decision"),
        "catalogDigest": route.get("catalogDigest"),
        "catalogProvider": route.get("catalogProvider"),
        "catalogDiscoveredAt": route.get("catalogDiscoveredAt"),
    }
    nullable_identity_fields = {"fallbackModel", "fallbackHostReasoning"}
    if any(
        value is None
        for key, value in route_identity.items()
        if key not in nullable_identity_fields
    ):
        raise WorkflowError("route is missing canonical identity fields")
    if _json_digest(route_identity) != route_digest:
        raise WorkflowError("route.routeDigest does not match its canonical identity")
    return tier, workers, mode, route_digest, execution_digest


def compile_plan(
    markdown: str,
    workflow_id: str,
    route: Any,
    *,
    requested_max_workers: int | None = None,
) -> dict[str, Any]:
    tier, route_workers, mode, route_digest, execution_digest = _route_values(route)
    workers = route_workers if requested_max_workers is None else requested_max_workers
    if workers > route_workers:
        raise WorkflowError(
            f"requested maxWorkers {workers} cannot exceed route maximum {route_workers}"
        )
    source_digest = hashlib.sha256(markdown.encode("utf-8")).hexdigest()
    graph = {
        "schemaVersion": 2,
        "workflowId": workflow_id,
        "generatedFrom": "tasks.md",
        "sourceDigest": source_digest,
        "routeBinding": {
            "routeDigest": route_digest,
            "executionSpecDigest": execution_digest,
        },
        "policy": {
            "tier": tier,
            "maxWorkers": workers,
            "tokenBudgetMode": mode,
            "retryLimit": 1,
            "shellPolicy": "deny",
            "allowedShellCommands": [],
        },
        "tasks": parse_tasks(markdown),
    }
    return TaskGraph.from_dict(graph).to_dict()


def canonical_json(graph: dict[str, Any]) -> str:
    return json.dumps(graph, ensure_ascii=False, indent=2, sort_keys=False) + "\n"


def write_compiled_graph(path: Path, graph: dict[str, Any], *, check: bool = False) -> bool:
    content = canonical_json(graph)
    if check:
        if not path.exists() or path.read_text(encoding="utf-8-sig") != content:
            raise WorkflowError(f"compiled graph drift detected: {path}")
        return False
    changed = not path.exists() or path.read_text(encoding="utf-8-sig") != content
    if changed:
        path.write_text(content, encoding="utf-8", newline="\n")
    return changed
