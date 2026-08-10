from __future__ import annotations

import hashlib
import hmac
import json
import tempfile
import unittest
from datetime import UTC, datetime
from pathlib import Path

from ueef_spec_workflow.adapters import host_status
from ueef_spec_workflow.customization import resolve_customizations
from ueef_spec_workflow.errors import WorkflowError
from ueef_spec_workflow.hierarchy import evaluate_hierarchy
from ueef_spec_workflow.lifecycle import prepare_workflow
from ueef_spec_workflow.safe_workflow import expand_safe_workflow

from .test_compiler import TASKS, route


class WorkflowExtensionTests(unittest.TestCase):
    VERIFIER_KEY = b"hierarchy-verifier-test-key-32-bytes!!"

    @staticmethod
    def hierarchy_verification(feature_id: str, workflow_id: str = "demo-flow") -> dict:
        receipt = {
            "schemaVersion": 2,
            "featureId": feature_id,
            "workflowId": workflow_id,
            "graphDigest": "a" * 64,
            "executionId": "execution-1",
            "status": "PASS",
            "independent": True,
            "evidenceDigest": "b" * 64,
            "diffDigest": "c" * 64,
            "verifierId": "reviewer-1",
            "keyId": "primary",
        }
        receipt["receiptDigest"] = hashlib.sha256(
            json.dumps(receipt, sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest()
        receipt["signature"] = hmac.new(
            WorkflowExtensionTests.VERIFIER_KEY,
            b"UEEF-HIERARCHY-VERIFICATION-V1\0" + receipt["receiptDigest"].encode("ascii"),
            hashlib.sha256,
        ).hexdigest()
        return receipt

    def evaluate(self, document: dict) -> dict:
        return evaluate_hierarchy(
            document,
            trusted_verifiers={"reviewer-1": {"primary": self.VERIFIER_KEY}},
        )

    def test_host_status_requires_explicit_evidence_for_runtime_verification(self) -> None:
        self.assertEqual(host_status()["codex"], "CONTRACT_ONLY")
        receipt = {
            "schemaVersion": 1,
            "adapter": "codex",
            "evidence": "real App Server smoke receipt",
            "observedAt": "2026-08-09T10:00:00Z",
            "result": "PASS",
        }
        digest = hashlib.sha256(
            json.dumps(receipt, sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest()
        evidence = {
            "schemaVersion": 1,
            "availableAdapters": ["codex", "generic"],
            "verified": [
                {
                    "adapter": "codex",
                    "receipt": receipt,
                    "receiptDigest": digest,
                }
            ],
        }
        status = host_status(evidence, now=datetime(2026, 8, 9, 10, 5, tzinfo=UTC))
        self.assertEqual(status["codex"], "VERIFIED_RUNTIME")
        self.assertEqual(status["claude"], "UNAVAILABLE")
        with self.assertRaisesRegex(WorkflowError, "stale"):
            stale = {**receipt, "observedAt": "2000-01-01T00:00:00Z"}
            host_status(
                {
                    **evidence,
                    "verified": [
                        {
                            **evidence["verified"][0],
                            "receipt": stale,
                            "receiptDigest": hashlib.sha256(
                                json.dumps(stale, sort_keys=True, separators=(",", ":")).encode()
                            ).hexdigest(),
                        }
                    ],
                },
                now=datetime(2026, 8, 9, 10, 5, tzinfo=UTC),
            )
        with self.assertRaisesRegex(WorkflowError, "does not match"):
            host_status(
                {**evidence, "verified": [{**evidence["verified"][0], "receiptDigest": "0" * 64}]},
                now=datetime(2026, 8, 9, 10, 5, tzinfo=UTC),
            )

    def test_hierarchy_requires_verified_children_for_done_rollup(self) -> None:
        report = self.evaluate(
            {
                "schemaVersion": 1,
                "features": [
                    {
                        "id": "root", "workflowId": "demo-flow", "graphDigest": "a" * 64,
                        "executionId": "execution-1", "children": ["child"], "status": "DONE",
                        "verification": self.hierarchy_verification("root"),
                    },
                    {
                        "id": "child", "workflowId": "demo-flow", "graphDigest": "a" * 64,
                        "executionId": "execution-1", "children": [], "status": "DONE",
                    },
                ],
            }
        )
        self.assertEqual(report["statuses"]["root"], "PENDING")
        verified_document = {
            "schemaVersion": 1,
            "features": [
                {
                    "id": feature_id, "workflowId": "demo-flow", "graphDigest": "a" * 64,
                    "executionId": "execution-1", "status": "DONE",
                    "verification": self.hierarchy_verification(feature_id),
                }
                for feature_id in ("one", "two")
            ],
        }
        self.assertEqual(
            self.evaluate(verified_document)["statuses"], {"one": "DONE", "two": "DONE"}
        )
        forged = {
            "schemaVersion": 1,
            "features": [{"id": "forged", "status": "DONE", "verified": True}],
        }
        with self.assertRaisesRegex(WorkflowError, "verified.*unsupported"):
            self.evaluate(forged)
        tampered = self.hierarchy_verification("verified")
        tampered["evidenceDigest"] = "d" * 64
        with self.assertRaisesRegex(WorkflowError, "receiptDigest"):
            self.evaluate(
                {
                    "schemaVersion": 1,
                    "features": [{
                        "id": "verified", "workflowId": "demo-flow", "graphDigest": "a" * 64,
                        "executionId": "execution-1", "status": "DONE", "verification": tampered,
                    }],
                }
            )
        forged_receipt = self.hierarchy_verification("forged-receipt")
        forged_receipt["evidenceDigest"] = "d" * 64
        statement = {
            key: value
            for key, value in forged_receipt.items()
            if key not in {"receiptDigest", "signature"}
        }
        forged_receipt["receiptDigest"] = hashlib.sha256(
            json.dumps(statement, sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest()
        forged_receipt["signature"] = hmac.new(
            b"attacker-key-that-is-not-trusted!!!",
            b"UEEF-HIERARCHY-VERIFICATION-V1\0"
            + forged_receipt["receiptDigest"].encode("ascii"),
            hashlib.sha256,
        ).hexdigest()
        with self.assertRaisesRegex(WorkflowError, "signature"):
            self.evaluate(
                {
                    "schemaVersion": 1,
                    "features": [{
                        "id": "forged-receipt", "workflowId": "demo-flow",
                        "graphDigest": "a" * 64, "executionId": "execution-1",
                        "status": "DONE", "verification": forged_receipt,
                    }],
                }
            )
        with self.assertRaisesRegex(WorkflowError, "cycle"):
            self.evaluate(
                {
                    "schemaVersion": 1,
                    "features": [
                        {"id": "a", "children": ["b"]},
                        {"id": "b", "children": ["a"]},
                    ],
                }
            )

    def test_customization_resolution_is_deterministic_and_route_clamped(self) -> None:
        item = {
            "id": "team-standard",
            "kind": "preset",
            "version": "1.0.0",
            "source": "project://presets/team-standard",
            "sha256": "a" * 64,
            "maxWorkers": 2,
            "permissions": ["read"],
            "rollback": "remove manifest",
        }
        first = resolve_customizations({"schemaVersion": 1, "items": [item]}, route_worker_cap=4)
        second = resolve_customizations({"schemaVersion": 1, "items": [item]}, route_worker_cap=4)
        self.assertEqual(first, second)
        with self.assertRaisesRegex(WorkflowError, "widen"):
            resolve_customizations(
                {"schemaVersion": 1, "items": [{**item, "maxWorkers": 5}]},
                route_worker_cap=4,
            )
        with self.assertRaisesRegex(WorkflowError, "forbidden"):
            resolve_customizations(
                {"schemaVersion": 1, "items": [{**item, "permissions": ["write-anywhere"]}]},
                route_worker_cap=4,
            )
        with self.assertRaisesRegex(WorkflowError, "route authority"):
            resolve_customizations(
                {"schemaVersion": 1, "items": [{**item, "tokenBudget": 999999999}]},
                route_worker_cap=4,
            )
        selected = resolve_customizations(
            {
                "schemaVersion": 1,
                "items": [
                    {**item, "sourceLevel": "core", "version": "1.0.0"},
                    {**item, "sourceLevel": "project", "version": "2.0.0", "sha256": "b" * 64},
                ],
            },
            route_worker_cap=4,
        )
        self.assertEqual(selected["items"][0]["version"], "2.0.0")

    def test_safe_workflow_expands_bounded_constructs_and_denies_shell(self) -> None:
        expanded = expand_safe_workflow(
            {
                "schemaVersion": 1,
                "steps": [
                    {"type": "if", "condition": "enabled", "then": [{"type": "task", "id": "A"}]},
                    {
                        "type": "fan-out",
                        "branches": [
                            [{"type": "task", "id": "B"}],
                            [{"type": "task", "id": "C"}],
                        ],
                    },
                    {"type": "while", "maxIterations": 2, "steps": [{"type": "task", "id": "D"}]},
                    {"type": "fan-in", "id": "JOIN"},
                ],
            },
            {"enabled": True},
        )
        self.assertEqual(len(expanded), 6)
        by_id = {item["id"]: item for item in expanded}
        self.assertEqual(by_id["I2-D"]["dependsOn"], ["I1-D"])
        self.assertEqual(set(by_id["JOIN"]["dependsOn"]), {"I2-D"})
        with self.assertRaisesRegex(WorkflowError, "forbidden"):
            expand_safe_workflow({"schemaVersion": 1, "steps": [{"type": "shell"}]})
        with self.assertRaisesRegex(WorkflowError, "fan-in id"):
            expand_safe_workflow({"schemaVersion": 1, "steps": [{"type": "fan-in", "id": None}]})

    def test_prepare_workflow_requires_every_ready_authored_phase(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            documents = {
                "constitution.md": "# Constitution\n\nStatus: READY\n",
                "spec.md": (
                    "# Specification\n\nStatus: READY\n\n- REQ-001: one\n"
                    "- REQ-002: two\n- AC-001: one\n- AC-002: two\n"
                ),
                "clarifications.md": "# Clarifications\n\nStatus: RESOLVED\n",
                "plan.md": (
                    "# Plan\n\nStatus: READY\n\n- REQ-001: one\n"
                    "- REQ-002: two\n- AC-001: one\n- AC-002: two\n"
                ),
                "tasks.md": TASKS + "\nREQ-001 AC-001\n",
            }
            for name, content in documents.items():
                (root / name).write_text(content, encoding="utf-8")
            report = prepare_workflow(root, "demo-flow", route())
            self.assertEqual(report["status"], "READY")

            documents["tasks.md"] = TASKS + "\nREQ-999 AC-999\n"
            documents["spec.md"] = "# Specification\n\nStatus: READY\n\n- REQ-999: x\n- AC-999: x\n"
            documents["plan.md"] = "# Plan\n\nStatus: READY\n\n- REQ-999: x\n- AC-999: x\n"
            for name, content in documents.items():
                (root / name).write_text(content, encoding="utf-8")
            with self.assertRaisesRegex(WorkflowError, "structured task trace"):
                prepare_workflow(root, "demo-flow", route())

    def test_prepare_ignores_narrative_ids_and_requires_plan_acceptance_mapping(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            documents = {
                "constitution.md": "# Constitution\n\nStatus: READY\n",
                "spec.md": (
                    "# Specification\n\nStatus: READY\n\n"
                    "Narrative mentions REQ-999 and AC-999 but does not declare them.\n"
                    "- REQ-001: declared\n- AC-001: declared\n"
                ),
                "clarifications.md": "# Clarifications\n\nStatus: RESOLVED\n",
                "plan.md": "# Plan\n\nStatus: READY\n\n- REQ-001: mapped\n",
                "tasks.md": TASKS,
            }
            for name, content in documents.items():
                (root / name).write_text(content, encoding="utf-8")
            with self.assertRaisesRegex(WorkflowError, "plan.md.*acceptance"):
                prepare_workflow(root, "demo-flow", route())


if __name__ == "__main__":
    unittest.main()
