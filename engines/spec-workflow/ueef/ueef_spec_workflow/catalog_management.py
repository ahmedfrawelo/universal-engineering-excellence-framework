"""Local, deterministic management for governed customization catalogs."""

from __future__ import annotations

import copy
import hashlib
import hmac
import json
import os
import re
from pathlib import Path
from typing import Any

from .customization import resolve_customization_plan
from .errors import WorkflowError
from .state import _exclusive_file_lock

_ID_CHARS = frozenset("abcdefghijklmnopqrstuvwxyz0123456789._-")
_KINDS = frozenset({"extension", "preset", "bundle"})
_SAFE_PERMISSIONS = frozenset({"read", "write-owned", "test", "verify"})
_SEMVER = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$")
_SOURCE_FIELDS = frozenset({"id", "sourceLevel", "priority", "installPolicy", "description"})
_ITEM_FIELDS = frozenset(
    {
        "id", "kind", "sourceId", "version", "source", "sha256", "maxWorkers",
        "permissions", "rollback", "requires", "members", "tokenBudget", "retryLimit",
        "description",
    }
)


def _canonical(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()


def _digest(document: Any) -> str:
    return hashlib.sha256(_canonical(document)).hexdigest()


def _valid_id(value: Any) -> bool:
    return (
        isinstance(value, str)
        and 1 <= len(value) <= 128
        and value[0].isalnum()
        and value[-1].isalnum()
        and not (set(value) - _ID_CHARS)
    )


def inspect_catalog(document: Any) -> dict[str, Any]:
    """Validate and return a bounded discovery inventory without executing content."""

    if not isinstance(document, dict) or document.get("schemaVersion") != 2:
        raise WorkflowError("customization catalog schemaVersion must be 2")
    if document.get("format") != "ueef-customization-catalog/v1":
        raise WorkflowError("customization catalog format is unsupported")
    sources = document.get("sources")
    items = document.get("items")
    if not isinstance(sources, list) or not 1 <= len(sources) <= 32:
        raise WorkflowError("catalog sources must contain 1-32 entries")
    if not isinstance(items, list) or len(items) > 200:
        raise WorkflowError("catalog items must contain at most 200 entries")
    source_ids: set[str] = set()
    normalized_sources: list[dict[str, Any]] = []
    for index, source in enumerate(sources):
        if not isinstance(source, dict) or not _valid_id(source.get("id")):
            raise WorkflowError(f"sources[{index}].id is invalid")
        if not set(source).issubset(_SOURCE_FIELDS):
            raise WorkflowError(f"sources[{index}] contains unsupported fields")
        source_id = source["id"]
        if source_id in source_ids:
            raise WorkflowError(f"duplicate catalog source: {source_id}")
        if source.get("sourceLevel") not in {"core", "extension", "preset", "project"}:
            raise WorkflowError(f"sources[{index}].sourceLevel is invalid")
        priority = source.get("priority")
        if (
            isinstance(priority, bool)
            or not isinstance(priority, int)
            or not 0 <= priority <= 10_000
        ):
            raise WorkflowError(f"sources[{index}].priority is invalid")
        if source.get("installPolicy") not in {"install-allowed", "discovery-only"}:
            raise WorkflowError(f"sources[{index}].installPolicy is invalid")
        source_ids.add(source_id)
        normalized_sources.append(dict(source))
    normalized_items: list[dict[str, Any]] = []
    item_keys: set[tuple[str, str]] = set()
    for index, item in enumerate(items):
        if not isinstance(item, dict) or not _valid_id(item.get("id")):
            raise WorkflowError(f"items[{index}].id is invalid")
        if not set(item).issubset(_ITEM_FIELDS):
            raise WorkflowError(f"items[{index}] contains unsupported or executable fields")
        if item.get("kind") not in _KINDS:
            raise WorkflowError(f"items[{index}].kind is invalid")
        if item.get("sourceId") not in source_ids:
            raise WorkflowError(f"items[{index}] references an unknown source")
        key = (item["id"], item["sourceId"])
        if key in item_keys:
            raise WorkflowError(f"duplicate catalog item identity: {key[0]}@{key[1]}")
        item_keys.add(key)
        if not isinstance(item.get("version"), str) or not _SEMVER.fullmatch(item["version"]):
            raise WorkflowError(f"items[{index}].version is invalid")
        if not isinstance(item.get("source"), str) or not item["source"].strip():
            raise WorkflowError(f"items[{index}].source is invalid")
        digest = item.get("sha256")
        if (
            not isinstance(digest, str)
            or len(digest) != 64
            or any(character not in "0123456789abcdef" for character in digest)
        ):
            raise WorkflowError(f"items[{index}].sha256 is invalid")
        max_workers = item.get("maxWorkers")
        if (
            isinstance(max_workers, bool)
            or not isinstance(max_workers, int)
            or not 1 <= max_workers <= 256
        ):
            raise WorkflowError(f"items[{index}].maxWorkers is invalid")
        permissions = item.get("permissions")
        if (
            not isinstance(permissions, list)
            or len(permissions) > 32
            or any(not isinstance(value, str) or not value for value in permissions)
            or not {value.casefold() for value in permissions}.issubset(_SAFE_PERMISSIONS)
        ):
            raise WorkflowError(f"items[{index}].permissions is invalid")
        if not isinstance(item.get("rollback"), str) or not item["rollback"].strip():
            raise WorkflowError(f"items[{index}].rollback is invalid")
        for field in ("tokenBudget", "retryLimit"):
            if field in item and (
                isinstance(item[field], bool)
                or not isinstance(item[field], int)
                or item[field] < 0
            ):
                raise WorkflowError(f"items[{index}].{field} is invalid")
        for field, limit in (("requires", 50), ("members", 100)):
            values = item.get(field, [])
            if (
                not isinstance(values, list)
                or len(values) > limit
                or any(not _valid_id(value) for value in values)
                or len(values) != len(set(values))
            ):
                raise WorkflowError(f"items[{index}].{field} is invalid")
        if item.get("kind") != "bundle" and item.get("members", []):
            raise WorkflowError(f"items[{index}].members is valid only for bundles")
        normalized_items.append(dict(item))
    normalized_sources.sort(key=lambda value: value["id"])
    normalized_items.sort(key=lambda value: (value["id"], value["sourceId"]))
    return {
        "schemaVersion": 1,
        "catalogDigest": _digest(document),
        "sources": normalized_sources,
        "items": normalized_items,
    }


def new_registry(document: Any) -> dict[str, Any]:
    inventory = inspect_catalog(document)
    return {
        "schemaVersion": 1,
        "catalogDigest": inventory["catalogDigest"],
        "sources": {
            source["id"]: {"enabled": True, "priority": source["priority"]}
            for source in inventory["sources"]
        },
        "selected": [],
    }


def validate_registry(document: Any, registry: Any) -> dict[str, Any]:
    inventory = inspect_catalog(document)
    if not isinstance(registry, dict) or registry.get("schemaVersion") != 1:
        raise WorkflowError("catalog registry schemaVersion must be 1")
    if registry.get("catalogDigest") != inventory["catalogDigest"]:
        raise WorkflowError("catalog registry is stale; reconcile it with the current catalog")
    raw_sources = registry.get("sources")
    selected = registry.get("selected")
    if not isinstance(raw_sources, dict) or set(raw_sources) != {
        source["id"] for source in inventory["sources"]
    }:
        raise WorkflowError("catalog registry sources do not match the catalog")
    normalized_sources: dict[str, dict[str, Any]] = {}
    for source_id, state in raw_sources.items():
        if not isinstance(state, dict) or not isinstance(state.get("enabled"), bool):
            raise WorkflowError(f"catalog source state is invalid: {source_id}")
        priority = state.get("priority")
        if (
            isinstance(priority, bool)
            or not isinstance(priority, int)
            or not 0 <= priority <= 10_000
        ):
            raise WorkflowError(f"catalog source priority is invalid: {source_id}")
        normalized_sources[source_id] = {"enabled": state["enabled"], "priority": priority}
    item_ids = {item["id"] for item in inventory["items"]}
    if (
        not isinstance(selected, list)
        or len(selected) > 100
        or any(not _valid_id(value) or value not in item_ids for value in selected)
        or len(selected) != len(set(selected))
    ):
        raise WorkflowError("catalog registry selected IDs are invalid")
    return {
        "schemaVersion": 1,
        "catalogDigest": inventory["catalogDigest"],
        "sources": dict(sorted(normalized_sources.items())),
        "selected": list(selected),
    }


def update_registry(
    document: Any,
    registry: Any,
    *,
    action: str,
    target: str | None = None,
    priority: int | None = None,
) -> dict[str, Any]:
    state = validate_registry(document, registry)
    if action in {"enable", "disable", "priority"}:
        if target not in state["sources"]:
            raise WorkflowError("catalog source target is unavailable")
        if action == "priority":
            if (
                isinstance(priority, bool)
                or not isinstance(priority, int)
                or not 0 <= priority <= 10_000
            ):
                raise WorkflowError("catalog priority must be between 0 and 10000")
            state["sources"][target]["priority"] = priority
        else:
            state["sources"][target]["enabled"] = action == "enable"
    elif action in {"select", "unselect"}:
        item_ids = {item["id"] for item in inspect_catalog(document)["items"]}
        if target not in item_ids:
            raise WorkflowError("catalog item target is unavailable")
        if action == "select" and target not in state["selected"]:
            if len(state["selected"]) >= 100:
                raise WorkflowError("catalog selection limit exceeded")
            state["selected"].append(target)
        elif action == "unselect":
            state["selected"] = [value for value in state["selected"] if value != target]
    else:
        raise WorkflowError("unsupported catalog registry action")
    state["selected"].sort()
    return state


def reconcile_registry(document: Any, registry: Any) -> dict[str, Any]:
    inventory = inspect_catalog(document)
    previous_sources = registry.get("sources", {}) if isinstance(registry, dict) else {}
    item_ids = {item["id"] for item in inventory["items"]}
    selected = registry.get("selected", []) if isinstance(registry, dict) else []
    state = new_registry(document)
    for source_id, current in state["sources"].items():
        previous = previous_sources.get(source_id) if isinstance(previous_sources, dict) else None
        if isinstance(previous, dict):
            enabled, priority = previous.get("enabled"), previous.get("priority")
            if isinstance(enabled, bool):
                current["enabled"] = enabled
            if (
                isinstance(priority, int)
                and not isinstance(priority, bool)
                and 0 <= priority <= 10_000
            ):
                current["priority"] = priority
    state["selected"] = sorted(
        value for value in selected if isinstance(value, str) and value in item_ids
    )[:100]
    return validate_registry(document, state)


def query_catalog(
    document: Any, *, action: str, term: str | None = None, target: str | None = None
) -> dict[str, Any]:
    inventory = inspect_catalog(document)
    if action == "list":
        items = inventory["items"]
    elif action == "search":
        if not isinstance(term, str) or not 1 <= len(term) <= 128:
            raise WorkflowError("catalog search term is required and bounded")
        needle = term.casefold()
        items = [
            item
            for item in inventory["items"]
            if needle in " ".join(
                str(item.get(key, "")) for key in ("id", "kind", "description", "version")
            ).casefold()
        ]
    elif action == "info":
        if not _valid_id(target):
            raise WorkflowError("catalog info target is invalid")
        items = [item for item in inventory["items"] if item["id"] == target]
        if not items:
            raise WorkflowError("catalog info target is unavailable")
    else:
        raise WorkflowError("unsupported catalog query action")
    return {**inventory, "action": action, "items": items}


def build_catalog_plan(
    document: Any,
    registry: Any,
    *,
    route_worker_cap: int,
    route_token_budget: int | None,
    route_retry_limit: int | None,
) -> dict[str, Any]:
    state = validate_registry(document, registry)
    filtered = json.loads(json.dumps(document))
    enabled = {source_id for source_id, value in state["sources"].items() if value["enabled"]}
    filtered["sources"] = [source for source in filtered["sources"] if source["id"] in enabled]
    for source in filtered["sources"]:
        source["priority"] = state["sources"][source["id"]]["priority"]
    filtered["items"] = [item for item in filtered["items"] if item["sourceId"] in enabled]
    if not filtered["sources"]:
        raise WorkflowError("catalog registry disables every source")
    if not state["selected"]:
        raise WorkflowError("catalog registry has no selected customizations")
    plan = resolve_customization_plan(
        filtered,
        selected=state["selected"],
        route_worker_cap=route_worker_cap,
        route_token_budget=route_token_budget,
        route_retry_limit=route_retry_limit,
    )
    return {**plan, "registryDigest": _digest(state)}


def maintain_catalog(
    document: Any,
    *,
    action: str,
    target: str | None = None,
    source_id: str | None = None,
    record: Any = None,
) -> dict[str, Any]:
    """Add, update, or remove catalog metadata; never fetch or execute package content."""

    inspect_catalog(document)
    updated = copy.deepcopy(document)
    collection_name = "sources" if action.endswith("source") else "items"
    collection = updated[collection_name]
    if action.startswith(("add-", "update-")):
        if not isinstance(record, dict):
            raise WorkflowError("catalog mutation record must be an object")
        record_id = record.get("id")
        if not _valid_id(record_id):
            raise WorkflowError("catalog mutation record id is invalid")
        positions = [
            index
            for index, value in enumerate(collection)
            if value.get("id") == record_id
            and (collection_name == "sources" or value.get("sourceId") == record.get("sourceId"))
        ]
        if action.startswith("add-"):
            if positions:
                raise WorkflowError("catalog mutation target already exists")
            collection.append(copy.deepcopy(record))
        else:
            if target != record_id or len(positions) != 1:
                raise WorkflowError("catalog update target must match one existing record")
            collection[positions[0]] = copy.deepcopy(record)
    elif action.startswith("remove-"):
        if not _valid_id(target):
            raise WorkflowError("catalog removal target is invalid")
        if collection_name == "items" and not _valid_id(source_id):
            raise WorkflowError("catalog item removal requires a source ID")
        positions = [
            index
            for index, value in enumerate(collection)
            if value.get("id") == target
            and (collection_name == "sources" or value.get("sourceId") == source_id)
        ]
        if not positions:
            raise WorkflowError("catalog removal target is unavailable")
        if collection_name == "sources" and any(
            item.get("sourceId") == target for item in updated["items"]
        ):
            raise WorkflowError("catalog source cannot be removed while items reference it")
        collection[:] = [
            value
            for value in collection
            if not (
                value.get("id") == target
                and (collection_name == "sources" or value.get("sourceId") == source_id)
            )
        ]
    else:
        raise WorkflowError("unsupported catalog maintenance action")
    inspect_catalog(updated)
    return updated


def write_json_atomic(path: Path, document: Any) -> None:
    if path.is_symlink():
        raise WorkflowError("catalog registry cannot replace a symbolic link")
    path = path.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    try:
        with temporary.open("xb") as stream:
            stream.write(_canonical(document) + b"\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


class CatalogRegistryStore:
    """Bounded cross-process transactions for the local catalog registry."""

    def __init__(self, path: Path) -> None:
        self.path = path.resolve()
        self.lock_path = self.path.with_name(self.path.name + ".lock")

    def _load_unlocked(self) -> Any:
        try:
            return json.loads(self.path.read_text(encoding="utf-8-sig"))
        except FileNotFoundError as exc:
            raise WorkflowError("catalog registry does not exist; initialize it first") from exc
        except json.JSONDecodeError as exc:
            raise WorkflowError(f"catalog registry JSON is invalid: {exc}") from exc

    def transact(
        self,
        document: Any,
        *,
        action: str,
        target: str | None = None,
        priority: int | None = None,
    ) -> dict[str, Any]:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with _exclusive_file_lock(self.lock_path):
            if action == "init":
                if self.path.exists():
                    raise WorkflowError("catalog registry already exists; use reconcile")
                state = new_registry(document)
            else:
                current = self._load_unlocked()
                if action == "reconcile":
                    state = reconcile_registry(document, current)
                elif action == "validate":
                    return validate_registry(document, current)
                else:
                    state = update_registry(
                        document,
                        current,
                        action=action,
                        target=target,
                        priority=priority,
                    )
            write_json_atomic(self.path, state)
            return state

    def load(self, document: Any) -> dict[str, Any]:
        with _exclusive_file_lock(self.lock_path):
            return validate_registry(document, self._load_unlocked())


class CatalogDocumentStore:
    """CAS-protected local catalog metadata updates with no remote code execution."""

    def __init__(self, path: Path) -> None:
        if path.is_symlink():
            raise WorkflowError("catalog document cannot be a symbolic link")
        self.path = path.resolve()
        self.lock_path = self.path.with_name(self.path.name + ".lock")

    def mutate(
        self,
        *,
        action: str,
        expected_digest: str,
        target: str | None = None,
        source_id: str | None = None,
        record: Any = None,
    ) -> dict[str, Any]:
        if (
            not isinstance(expected_digest, str)
            or len(expected_digest) != 64
            or any(character not in "0123456789abcdef" for character in expected_digest)
        ):
            raise WorkflowError("catalog mutation requires the current SHA-256 catalog digest")
        with _exclusive_file_lock(self.lock_path):
            try:
                document = json.loads(self.path.read_text(encoding="utf-8-sig"))
            except FileNotFoundError as exc:
                raise WorkflowError("catalog document does not exist") from exc
            except json.JSONDecodeError as exc:
                raise WorkflowError(f"catalog document JSON is invalid: {exc}") from exc
            current_digest = inspect_catalog(document)["catalogDigest"]
            if not hmac.compare_digest(current_digest, expected_digest):
                raise WorkflowError("catalog changed since it was inspected")
            updated = maintain_catalog(
                document,
                action=action,
                target=target,
                source_id=source_id,
                record=record,
            )
            write_json_atomic(self.path, updated)
            return inspect_catalog(updated)


# Backward-compatible public name for direct registry materialization.
write_registry = write_json_atomic
