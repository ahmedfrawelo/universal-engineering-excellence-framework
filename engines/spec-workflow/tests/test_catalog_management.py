from __future__ import annotations

import copy
import json
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any, cast

from ueef_spec_workflow.catalog_management import (
    CatalogDocumentStore,
    CatalogRegistryStore,
    build_catalog_plan,
    new_registry,
    query_catalog,
    reconcile_registry,
    update_registry,
    validate_registry,
    write_registry,
)
from ueef_spec_workflow.cli import build_parser
from ueef_spec_workflow.errors import WorkflowError


def _item(item_id: str, source_id: str, **extra: object) -> dict[str, object]:
    return {
        "id": item_id,
        "kind": "extension",
        "sourceId": source_id,
        "version": "1.0.0",
        "source": f"content://{item_id}",
        "sha256": "a" * 64,
        "maxWorkers": 2,
        "permissions": ["read"],
        "rollback": "deactivate",
        **extra,
    }


def _catalog() -> dict[str, object]:
    return {
        "schemaVersion": 2,
        "format": "ueef-customization-catalog/v1",
        "sources": [
            {
                "id": "core",
                "sourceLevel": "core",
                "priority": 10,
                "installPolicy": "install-allowed",
            },
            {
                "id": "project",
                "sourceLevel": "project",
                "priority": 20,
                "installPolicy": "install-allowed",
            },
        ],
        "items": [
            _item("lint", "core", description="Core lint"),
            _item("lint", "project", version="2.0.0", sha256="b" * 64),
            _item("quality", "core", requires=["lint"]),
        ],
    }


class CatalogManagementTests(unittest.TestCase):
    def test_query_supports_list_search_and_info_without_execution(self) -> None:
        catalog = _catalog()
        listed = query_catalog(catalog, action="list")
        searched = query_catalog(catalog, action="search", term="core lint")
        info = query_catalog(catalog, action="info", target="lint")
        self.assertEqual(len(listed["items"]), 3)
        self.assertEqual([item["sourceId"] for item in searched["items"]], ["core"])
        self.assertEqual(len(info["items"]), 2)

    def test_registry_manages_sources_selections_and_builds_route_clamped_plan(self) -> None:
        catalog = _catalog()
        registry = new_registry(catalog)
        registry = update_registry(catalog, registry, action="select", target="quality")
        registry = update_registry(
            catalog, registry, action="priority", target="project", priority=1
        )
        plan = build_catalog_plan(
            catalog,
            registry,
            route_worker_cap=2,
            route_token_budget=None,
            route_retry_limit=1,
        )
        self.assertEqual(plan["activationOrder"], ["lint", "quality"])
        self.assertEqual(plan["items"][0]["version"], "2.0.0")
        self.assertEqual(len(plan["registryDigest"]), 64)

        disabled = update_registry(catalog, registry, action="disable", target="project")
        fallback = build_catalog_plan(
            catalog,
            disabled,
            route_worker_cap=2,
            route_token_budget=None,
            route_retry_limit=1,
        )
        self.assertEqual(fallback["items"][0]["version"], "1.0.0")

    def test_registry_is_atomic_stale_aware_and_reconcilable(self) -> None:
        catalog = _catalog()
        registry = new_registry(catalog)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "catalog-registry.json"
            write_registry(path, registry)
            self.assertEqual(
                json.loads(path.read_text())["catalogDigest"], registry["catalogDigest"]
            )
            self.assertEqual(list(path.parent.glob("*.tmp")), [])
        changed = copy.deepcopy(catalog)
        cast(list[Any], changed["items"]).append(_item("format", "core"))
        with self.assertRaisesRegex(WorkflowError, "stale"):
            validate_registry(changed, registry)
        reconciled = reconcile_registry(changed, registry)
        self.assertNotEqual(reconciled["catalogDigest"], registry["catalogDigest"])

    def test_cli_exposes_governed_management_lifecycle(self) -> None:
        parser = build_parser()
        for command, extra in (
            ("catalog-query", ["--action", "list"]),
            ("catalog-registry", ["--registry", "registry.json", "--action", "init"]),
            (
                "catalog-build",
                ["--registry", "registry.json", "--route", "route.json"],
            ),
            (
                "catalog-maintain",
                [
                    "--action", "remove-item", "--target", "lint", "--source-id", "core",
                    "--expected-digest", "a" * 64,
                ],
            ),
        ):
            args = parser.parse_args([command, "--catalog", "catalog.json", *extra])
            self.assertTrue(callable(args.handler))

    def test_catalog_metadata_add_update_remove_is_cas_protected(self) -> None:
        catalog = _catalog()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "catalog.json"
            path.write_text(json.dumps(catalog), encoding="utf-8")
            store = CatalogDocumentStore(path)
            digest = query_catalog(catalog, action="list")["catalogDigest"]
            source = {
                "id": "team",
                "sourceLevel": "project",
                "priority": 5,
                "installPolicy": "install-allowed",
            }
            added = store.mutate(
                action="add-source", expected_digest=digest, record=source
            )
            self.assertIn("team", [value["id"] for value in added["sources"]])
            with self.assertRaisesRegex(WorkflowError, "changed"):
                store.mutate(action="remove-source", target="team", expected_digest=digest)
            removed = store.mutate(
                action="remove-source",
                target="team",
                expected_digest=added["catalogDigest"],
            )
            self.assertNotIn("team", [value["id"] for value in removed["sources"]])

    def test_item_mutation_is_bound_to_item_and_source_identity(self) -> None:
        catalog = _catalog()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "catalog.json"
            path.write_text(json.dumps(catalog), encoding="utf-8")
            store = CatalogDocumentStore(path)
            digest = query_catalog(catalog, action="list")["catalogDigest"]
            project_lint = _item(
                "lint", "project", version="3.0.0", sha256="c" * 64
            )
            updated = store.mutate(
                action="update-item",
                target="lint",
                record=project_lint,
                expected_digest=digest,
            )
            lint_versions = {
                item["sourceId"]: item["version"]
                for item in updated["items"]
                if item["id"] == "lint"
            }
            self.assertEqual(lint_versions, {"core": "1.0.0", "project": "3.0.0"})
            removed = store.mutate(
                action="remove-item",
                target="lint",
                source_id="core",
                expected_digest=updated["catalogDigest"],
            )
            self.assertEqual(
                [
                    (item["id"], item["sourceId"])
                    for item in removed["items"]
                    if item["id"] == "lint"
                ],
                [("lint", "project")],
            )

    def test_catalog_rejects_malformed_duplicate_and_executable_metadata(self) -> None:
        catalog = _catalog()
        duplicate = copy.deepcopy(catalog)
        duplicate_items = cast(list[Any], duplicate["items"])
        duplicate_items.append(copy.deepcopy(duplicate_items[0]))
        with self.assertRaisesRegex(WorkflowError, "duplicate catalog item"):
            query_catalog(duplicate, action="list")
        for bad in (
            {"id": "bad", "kind": "extension", "sourceId": "core"},
            {**_item("bad", "core"), "command": "dangerous"},
        ):
            with tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "catalog.json"
                path.write_text(json.dumps(catalog), encoding="utf-8")
                store = CatalogDocumentStore(path)
                digest = query_catalog(catalog, action="list")["catalogDigest"]
                with self.assertRaises(WorkflowError):
                    store.mutate(
                        action="add-item", expected_digest=digest, record=bad
                    )

    def test_registry_transactions_serialize_updates_and_reject_duplicate_init(self) -> None:
        catalog = _catalog()
        with tempfile.TemporaryDirectory() as directory:
            store = CatalogRegistryStore(Path(directory) / "registry.json")
            store.transact(catalog, action="init")
            with self.assertRaisesRegex(WorkflowError, "already exists"):
                store.transact(catalog, action="init")
            with ThreadPoolExecutor(max_workers=2) as executor:
                futures = [
                    executor.submit(store.transact, catalog, action="select", target=target)
                    for target in ("lint", "quality")
                ]
                for future in futures:
                    future.result(timeout=10)
            self.assertEqual(store.load(catalog)["selected"], ["lint", "quality"])


if __name__ == "__main__":
    unittest.main()
