from __future__ import annotations

import pathlib
import unittest

from ueef_spec_workflow.customization import resolve_customization_plan
from ueef_spec_workflow.errors import WorkflowError
from ueef_spec_workflow.safe_workflow import compose_safe_workflow


def item(item_id: str, kind: str, source: str, **extra: object) -> dict[str, object]:
    return {
        "id": item_id,
        "kind": kind,
        "sourceId": source,
        "version": "1.0.0",
        "source": f"content://{item_id}",
        "sha256": "a" * 64,
        "maxWorkers": 2,
        "permissions": ["read"],
        "rollback": "deactivate",
        **extra,
    }


class CatalogCompositionTests(unittest.TestCase):
    def test_production_package_and_entrypoints_have_no_reference_dependency(self) -> None:
        engine_root = pathlib.Path(__file__).resolve().parents[1]
        package_root = engine_root / "ueef" / "ueef_spec_workflow"
        repository_root = engine_root.parents[1]
        scripts_root = repository_root / "scripts"
        production_files = list(package_root.glob("*.py"))
        production_files.extend(scripts_root.glob("invoke-spec-workflow-*"))
        production_files.extend(scripts_root.glob("new-spec-workflow.ps1"))
        forbidden = ("specify_cli", "upstream/spec-kit", "upstream\\spec-kit")
        violations = []
        for source in production_files:
            text = source.read_text(encoding="utf-8")
            if any(token in text for token in forbidden):
                violations.append(str(source.relative_to(repository_root)))
        self.assertEqual(violations, [])

    def test_catalog_resolves_bundle_dependencies_with_project_precedence(self) -> None:
        document = {
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
                    "priority": 10,
                    "installPolicy": "install-allowed",
                },
            ],
            "items": [
                item("lint", "extension", "core"),
                item("lint", "extension", "project", version="2.0.0", sha256="b" * 64),
                item("strict", "preset", "core", requires=["lint"]),
                item("delivery", "bundle", "core", members=["strict"]),
            ],
        }
        first = resolve_customization_plan(document, selected=["delivery"], route_worker_cap=2)
        second = resolve_customization_plan(document, selected=["delivery"], route_worker_cap=2)
        self.assertEqual(first, second)
        self.assertEqual(first["activationOrder"], ["lint", "strict", "delivery"])
        self.assertEqual(first["items"][0]["version"], "2.0.0")

    def test_catalog_fails_closed_on_discovery_cycles_and_ambiguous_sources(self) -> None:
        base = {
            "schemaVersion": 2,
            "format": "ueef-customization-catalog/v1",
            "sources": [
                {
                    "id": "community",
                    "sourceLevel": "extension",
                    "priority": 20,
                    "installPolicy": "discovery-only",
                }
            ],
            "items": [item("a", "extension", "community")],
        }
        with self.assertRaisesRegex(WorkflowError, "discovery-only"):
            resolve_customization_plan(base, selected=["a"], route_worker_cap=2)
        cyclic = {
            **base,
            "sources": [{**base["sources"][0], "installPolicy": "install-allowed"}],
            "items": [
                item("a", "extension", "community", requires=["b"]),
                item("b", "preset", "community", requires=["a"]),
            ],
        }
        with self.assertRaisesRegex(WorkflowError, "cycle"):
            resolve_customization_plan(cyclic, selected=["a"], route_worker_cap=2)

    def test_spec_kit_adapter_and_overlays_produce_safe_digest_bound_plan(self) -> None:
        workflow = {
            "schema_version": "1.0",
            "workflow": {"id": "delivery", "name": "Delivery", "version": "1.0.0"},
            "steps": [{"type": "task", "id": "review", "title": "Review"}],
        }
        overlays = [
            {
                "id": "quality",
                "extends": "delivery",
                "sourceLevel": "preset",
                "priority": 10,
                "edits": [
                    {
                        "operation": "insert_before",
                        "anchor": "review",
                        "step": {"type": "task", "id": "test"},
                    }
                ],
            },
            {
                "id": "project",
                "extends": "delivery",
                "sourceLevel": "project",
                "priority": 10,
                "edits": [
                    {
                        "operation": "insert_after",
                        "anchor": "review",
                        "step": {"type": "task", "id": "ship"},
                    }
                ],
            },
        ]
        result = compose_safe_workflow(workflow, overlays, adapter="spec-kit/v0.16")
        self.assertEqual([step["id"] for step in result["expanded"]], ["test", "review", "ship"])
        self.assertEqual(
            result, compose_safe_workflow(workflow, overlays, adapter="spec-kit/v0.16")
        )

    def test_adapter_and_overlay_reject_executable_or_ambiguous_content(self) -> None:
        unsafe = {
            "schema_version": "1.0",
            "workflow": {"id": "unsafe", "name": "Unsafe", "version": "1.0.0"},
            "steps": [{"type": "shell", "id": "run"}],
        }
        with self.assertRaisesRegex(WorkflowError, "forbidden"):
            compose_safe_workflow(unsafe, [], adapter="spec-kit/v0.16")
        human_gate = {
            "schema_version": "1.0",
            "workflow": {"id": "approval", "name": "Approval", "version": "1.0.0"},
            "steps": [{"type": "gate", "id": "review"}],
        }
        with self.assertRaisesRegex(WorkflowError, "human gate.*approval-bound"):
            compose_safe_workflow(human_gate, [], adapter="spec-kit/v0.16")
        base = {"schemaVersion": 1, "workflowId": "flow", "steps": [{"type": "task", "id": "a"}]}
        overlays = [
            {
                "id": "one",
                "extends": "flow",
                "sourceLevel": "preset",
                "priority": 1,
                "edits": [{"operation": "remove", "anchor": "a"}],
            },
            {
                "id": "two",
                "extends": "flow",
                "sourceLevel": "preset",
                "priority": 1,
                "edits": [
                    {"operation": "replace", "anchor": "a", "step": {"type": "task", "id": "b"}}
                ],
            },
        ]
        with self.assertRaisesRegex(WorkflowError, "ambiguous"):
            compose_safe_workflow(base, overlays)

    def test_adapter_resolves_only_supplied_boolean_conditions(self) -> None:
        workflow = {
            "schema_version": "1.0",
            "workflow": {
                "id": "conditional",
                "name": "Conditional",
                "version": "1.0.0",
            },
            "steps": [
                {
                    "type": "if",
                    "condition": "enabled",
                    "then": [{"type": "task", "id": "yes"}],
                    "else": [{"type": "task", "id": "no"}],
                }
            ],
        }
        result = compose_safe_workflow(
            workflow,
            [],
            adapter="spec-kit/v0.16",
            context={"enabled": False},
        )
        self.assertEqual([step["id"] for step in result["expanded"]], ["no"])
        with self.assertRaisesRegex(WorkflowError, "supplied boolean"):
            compose_safe_workflow(workflow, [], adapter="spec-kit/v0.16")

    def test_reference_control_flow_semantics_map_to_bounded_native_dag(self) -> None:
        workflow = {
            "schema_version": "1.0",
            "workflow": {"id": "control-flow", "name": "Control", "version": "1.0.0"},
            "steps": [
                {"type": "task", "id": "start"},
                {
                    "type": "if",
                    "condition": "enabled",
                    "then": [{"type": "task", "id": "conditional"}],
                },
                {
                    "type": "fan-out",
                    "branches": [
                        [{"type": "task", "id": "left"}],
                        [{"type": "task", "id": "right"}],
                    ],
                },
                {
                    "type": "while",
                    "condition": "repeatEnabled",
                    "maxIterations": 2,
                    "steps": [{"type": "task", "id": "repeat"}],
                },
                {"type": "fan-in", "id": "join"},
            ],
        }
        result = compose_safe_workflow(
            workflow,
            [],
            adapter="spec-kit/v0.16",
            context={"enabled": True, "repeatEnabled": True},
        )
        by_id = {step["id"]: step for step in result["expanded"]}
        self.assertEqual(by_id["conditional"]["dependsOn"], ["start"])
        self.assertEqual(by_id["B1-left"]["dependsOn"], ["conditional"])
        self.assertEqual(by_id["B2-right"]["dependsOn"], ["conditional"])
        self.assertEqual(set(by_id["I1-repeat"]["dependsOn"]), {"B1-left", "B2-right"})
        self.assertEqual(by_id["I2-repeat"]["dependsOn"], ["I1-repeat"])
        self.assertEqual(by_id["join"]["dependsOn"], ["I2-repeat"])

    def test_bounded_loops_use_only_supplied_boolean_conditions(self) -> None:
        def expand(kind: str, enabled: bool, maximum: int = 3) -> list[str]:
            workflow = {
                "schemaVersion": 1,
                "workflowId": "loop",
                "steps": [{
                    "type": kind,
                    "condition": "continueLoop",
                    "maxIterations": maximum,
                    "steps": [{"type": "task", "id": "body"}],
                }],
            }
            result = compose_safe_workflow(
                workflow, [], context={"continueLoop": enabled}
            )
            return [step["id"] for step in result["expanded"]]

        self.assertEqual(expand("while", False), [])
        self.assertEqual(expand("while", True), ["I1-body", "I2-body", "I3-body"])
        self.assertEqual(expand("do-while", False), ["I1-body"])
        self.assertEqual(
            expand("do-while", True), ["I1-body", "I2-body", "I3-body"]
        )
        with self.assertRaisesRegex(WorkflowError, "supplied boolean"):
            compose_safe_workflow(
                {
                    "schemaVersion": 1,
                    "workflowId": "unsafe-loop",
                    "steps": [{
                        "type": "while",
                        "condition": "count < 3",
                        "maxIterations": 3,
                        "steps": [{"type": "task", "id": "body"}],
                    }],
                },
                [],
                context={"continueLoop": True},
            )
        for invalid in (0, 21):
            with self.assertRaisesRegex(WorkflowError, "1 through 20"):
                expand("while", True, invalid)


if __name__ == "__main__":
    unittest.main()
