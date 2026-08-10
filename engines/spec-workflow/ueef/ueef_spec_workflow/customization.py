"""Deterministic permission-clamped extension, preset, and bundle resolution."""

from __future__ import annotations

import hashlib
import json
import re
from typing import Any

from .errors import WorkflowError

_KINDS = {"extension": 1, "preset": 2, "bundle": 3}
_PRECEDENCE = {"core": 0, "extension": 1, "preset": 2, "project": 3}
_SAFE_PERMISSIONS = frozenset({"read", "write-owned", "test", "verify"})
_CATALOG_ID = re.compile(r"^[a-z0-9](?:[a-z0-9._-]{0,126}[a-z0-9])?$")
_SEMVER = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$")


def resolve_customizations(
    document: Any,
    *,
    route_worker_cap: int,
    route_token_budget: int | None = None,
    route_retry_limit: int | None = None,
    allowed_permissions: frozenset[str] = _SAFE_PERMISSIONS,
) -> dict[str, Any]:
    if not isinstance(document, dict) or document.get("schemaVersion") != 1:
        raise WorkflowError("customization catalog schemaVersion must be 1")
    raw = document.get("items", [])
    if not isinstance(raw, list) or len(raw) > 100:
        raise WorkflowError("customization catalog items must be a bounded array")
    candidates: dict[str, dict[str, Any]] = {}
    for index, item in enumerate(raw):
        if not isinstance(item, dict):
            raise WorkflowError(f"items[{index}] must be an object")
        item_id = item.get("id")
        kind = item.get("kind")
        version = item.get("version")
        source = item.get("source")
        digest = item.get("sha256")
        max_workers = item.get("maxWorkers", route_worker_cap)
        permissions = item.get("permissions", [])
        source_level = item.get("sourceLevel", kind if kind in {"extension", "preset"} else "core")
        has_token_budget = "tokenBudget" in item
        has_retry_limit = "retryLimit" in item
        token_budget = item.get("tokenBudget", route_token_budget)
        retry_limit = item.get("retryLimit", route_retry_limit)
        rollback = item.get("rollback")
        if not isinstance(item_id, str) or not item_id.strip():
            raise WorkflowError(f"items[{index}].id is invalid")
        if kind not in _KINDS:
            raise WorkflowError(f"items[{index}].kind is invalid")
        if not all(
            isinstance(value, str) and value.strip() for value in (version, source, rollback)
        ):
            raise WorkflowError(f"items[{index}] requires version, source, and rollback")
        if (
            not isinstance(digest, str)
            or len(digest) != 64
            or any(c not in "0123456789abcdef" for c in digest)
        ):
            raise WorkflowError(f"items[{index}].sha256 is invalid")
        if isinstance(max_workers, bool) or not isinstance(max_workers, int) or max_workers < 1:
            raise WorkflowError(f"items[{index}].maxWorkers is invalid")
        if max_workers > route_worker_cap:
            raise WorkflowError(f"items[{index}] cannot widen the route worker cap")
        if source_level not in _PRECEDENCE:
            raise WorkflowError(f"items[{index}].sourceLevel is invalid")
        if token_budget is not None and (
            isinstance(token_budget, bool) or not isinstance(token_budget, int) or token_budget < 0
        ):
            raise WorkflowError(f"items[{index}].tokenBudget is invalid")
        if (
            route_token_budget is not None
            and token_budget is not None
            and token_budget > route_token_budget
        ):
            raise WorkflowError(f"items[{index}] cannot widen the route token budget")
        if has_token_budget and route_token_budget is None:
            raise WorkflowError(f"items[{index}] tokenBudget requires route authority")
        if retry_limit is not None and (
            isinstance(retry_limit, bool) or not isinstance(retry_limit, int) or retry_limit < 0
        ):
            raise WorkflowError(f"items[{index}].retryLimit is invalid")
        if (
            route_retry_limit is not None
            and retry_limit is not None
            and retry_limit > route_retry_limit
        ):
            raise WorkflowError(f"items[{index}] cannot widen the route retry limit")
        if has_retry_limit and route_retry_limit is None:
            raise WorkflowError(f"items[{index}] retryLimit requires route authority")
        if not isinstance(permissions, list) or any(
            not isinstance(value, str) for value in permissions
        ):
            raise WorkflowError(f"items[{index}].permissions must be strings")
        normalized_permissions = {value.casefold() for value in permissions}
        if not normalized_permissions.issubset(allowed_permissions):
            raise WorkflowError(f"items[{index}] requests a forbidden permission")
        candidate = {
            "id": item_id,
            "kind": kind,
            "sourceLevel": source_level,
            "version": version,
            "source": source,
            "sha256": digest,
            "maxWorkers": max_workers,
            "permissions": sorted(normalized_permissions),
            "tokenBudget": token_budget,
            "retryLimit": retry_limit,
            "rollback": rollback,
        }
        previous = candidates.get(item_id)
        if previous and _PRECEDENCE[previous["sourceLevel"]] == _PRECEDENCE[source_level]:
            raise WorkflowError(f"items[{index}].id conflicts at the same source precedence")
        if previous is None or _PRECEDENCE[source_level] > _PRECEDENCE[previous["sourceLevel"]]:
            candidates[item_id] = candidate
    normalized = list(candidates.values())
    normalized.sort(key=lambda value: (_KINDS[value["kind"]], value["id"]))
    canonical = json.dumps(normalized, sort_keys=True, separators=(",", ":"))
    return {
        "schemaVersion": 1,
        "precedence": ["project", "preset", "extension", "core"],
        "items": normalized,
        "digest": hashlib.sha256(canonical.encode()).hexdigest(),
    }


def resolve_customization_plan(
    document: Any,
    *,
    selected: list[str],
    route_worker_cap: int,
    route_token_budget: int | None = None,
    route_retry_limit: int | None = None,
) -> dict[str, Any]:
    """Resolve a source-aware dependency and bundle graph without executing content."""

    if not isinstance(document, dict) or document.get("schemaVersion") != 2:
        raise WorkflowError("customization plan schemaVersion must be 2")
    if document.get("format") != "ueef-customization-catalog/v1":
        raise WorkflowError("customization plan format is unsupported")
    sources = document.get("sources")
    items = document.get("items")
    if not isinstance(sources, list) or not 1 <= len(sources) <= 32:
        raise WorkflowError("catalog sources must contain 1-32 entries")
    if not isinstance(items, list) or len(items) > 200:
        raise WorkflowError("catalog items must be an array of at most 200 entries")
    if not isinstance(selected, list) or not 1 <= len(selected) <= 100:
        raise WorkflowError("selected customizations must contain 1-100 IDs")
    source_map: dict[str, dict[str, Any]] = {}
    for index, source in enumerate(sources):
        if not isinstance(source, dict):
            raise WorkflowError(f"sources[{index}] must be an object")
        source_id = source.get("id")
        level = source.get("sourceLevel")
        priority = source.get("priority")
        policy = source.get("installPolicy")
        if not isinstance(source_id, str) or not _CATALOG_ID.fullmatch(source_id):
            raise WorkflowError(f"sources[{index}].id is invalid")
        if source_id in source_map:
            raise WorkflowError(f"duplicate catalog source: {source_id}")
        if level not in _PRECEDENCE:
            raise WorkflowError(f"sources[{index}].sourceLevel is invalid")
        if (
            isinstance(priority, bool)
            or not isinstance(priority, int)
            or not 0 <= priority <= 10_000
        ):
            raise WorkflowError(f"sources[{index}].priority is invalid")
        if policy not in {"install-allowed", "discovery-only"}:
            raise WorkflowError(f"sources[{index}].installPolicy is invalid")
        source_map[source_id] = dict(source)
    candidates: dict[str, list[dict[str, Any]]] = {}
    for index, item in enumerate(items):
        if not isinstance(item, dict):
            raise WorkflowError(f"items[{index}] must be an object")
        item_id = item.get("id")
        source_id = item.get("sourceId")
        dependencies = item.get("requires", [])
        members = item.get("members", [])
        if not isinstance(item_id, str) or not _CATALOG_ID.fullmatch(item_id):
            raise WorkflowError(f"items[{index}].id is invalid")
        if source_id not in source_map:
            raise WorkflowError(f"items[{index}] references an unknown source")
        if not _SEMVER.fullmatch(str(item.get("version", ""))):
            raise WorkflowError(f"items[{index}].version is invalid")
        if (
            not isinstance(dependencies, list)
            or len(dependencies) > 50
            or any(
                not isinstance(value, str) or not _CATALOG_ID.fullmatch(value)
                for value in dependencies
            )
        ):
            raise WorkflowError(f"items[{index}].requires is invalid")
        if (
            not isinstance(members, list)
            or len(members) > 100
            or any(
                not isinstance(value, str) or not _CATALOG_ID.fullmatch(value) for value in members
            )
        ):
            raise WorkflowError(f"items[{index}].members is invalid")
        if item.get("kind") != "bundle" and members:
            raise WorkflowError(f"items[{index}] members are valid only for bundles")
        source = source_map[source_id]
        candidate = {
            **item,
            "sourceLevel": source["sourceLevel"],
            "installPolicy": source["installPolicy"],
            "requires": list(dict.fromkeys(dependencies)),
            "members": list(dict.fromkeys(members)),
        }
        candidates.setdefault(item_id, []).append(candidate)
    winners: dict[str, dict[str, Any]] = {}
    for item_id, versions in candidates.items():
        versions.sort(
            key=lambda value: (
                _PRECEDENCE[value["sourceLevel"]],
                -source_map[value["sourceId"]]["priority"],
            ),
            reverse=True,
        )
        if len(versions) > 1:
            first, second = versions[:2]
            first_key = (
                _PRECEDENCE[first["sourceLevel"]],
                source_map[first["sourceId"]]["priority"],
            )
            second_key = (
                _PRECEDENCE[second["sourceLevel"]],
                source_map[second["sourceId"]]["priority"],
            )
            if first_key == second_key:
                raise WorkflowError(f"ambiguous catalog item at equal precedence: {item_id}")
        winners[item_id] = versions[0]
    order: list[str] = []
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(item_id: str) -> None:
        if item_id in visited:
            return
        if item_id in visiting:
            raise WorkflowError(f"customization dependency cycle contains {item_id}")
        item = winners.get(item_id)
        if item is None:
            raise WorkflowError(f"customization dependency is unavailable: {item_id}")
        if item["installPolicy"] != "install-allowed":
            raise WorkflowError(f"customization is discovery-only: {item_id}")
        visiting.add(item_id)
        for dependency in [*item["requires"], *item["members"]]:
            visit(dependency)
        visiting.remove(item_id)
        visited.add(item_id)
        order.append(item_id)

    for item_id in selected:
        if not isinstance(item_id, str) or not _CATALOG_ID.fullmatch(item_id):
            raise WorkflowError("selected customization ID is invalid")
        visit(item_id)
    flattened = []
    for item_id in order:
        item = winners[item_id]
        flattened.append(
            {
                key: value
                for key, value in item.items()
                if key not in {"sourceId", "installPolicy", "requires", "members"}
            }
        )
    policy = resolve_customizations(
        {"schemaVersion": 1, "items": flattened},
        route_worker_cap=route_worker_cap,
        route_token_budget=route_token_budget,
        route_retry_limit=route_retry_limit,
    )
    resolved = [{**winners[item["id"]], "policy": item} for item in policy["items"]]
    resolved.sort(key=lambda value: order.index(value["id"]))
    canonical = json.dumps(resolved, sort_keys=True, separators=(",", ":"))
    return {
        "schemaVersion": 2,
        "format": "ueef-customization-plan/v1",
        "selected": list(dict.fromkeys(selected)),
        "activationOrder": order,
        "items": resolved,
        "digest": hashlib.sha256(canonical.encode()).hexdigest(),
    }
