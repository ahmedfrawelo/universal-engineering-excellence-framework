from __future__ import annotations

import copy
import hashlib
import json
import tempfile
import unittest
from datetime import UTC, datetime, timedelta
from pathlib import Path

from ueef_spec_workflow.approvals import ApprovalLedger, ApprovalStore
from ueef_spec_workflow.errors import WorkflowError
from ueef_spec_workflow.portfolio import orchestrate_portfolio


class ApprovalLedgerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.binding = {
            "workflowId": "release-flow",
            "graphDigest": "a" * 64,
            "executionId": "execution-1",
            "taskId": "task-1",
            "artifactDigest": "b" * 64,
        }
        self.document = {
            "schemaVersion": 2,
            "gates": [
                {
                    "id": "production-release",
                    **self.binding,
                    "approvers": [
                        {"identity": "user:alice", "role": "release-manager"},
                        {"identity": "user:bob", "role": "security-reviewer"},
                    ],
                    "threshold": 2,
                    "expiresAt": "2026-08-10T00:00:00Z",
                }
            ],
            "events": [],
        }
        self.now = datetime(2026, 8, 9, 12, tzinfo=UTC)

    def record(self, ledger: ApprovalLedger, identity: str, role: str, action: str) -> None:
        ledger.record(
            "production-release", identity, role, action, "c" * 64, self.binding,
            now=self.now + timedelta(seconds=len(ledger.events)),
        )

    def test_approval_is_identity_bound_durable_and_revocable(self) -> None:
        ledger = ApprovalLedger.from_dict(self.document)
        self.record(ledger, "user:alice", "release-manager", "GRANT")
        self.record(ledger, "user:bob", "security-reviewer", "GRANT")
        restored = ApprovalLedger.from_dict(ledger.to_dict())
        status = restored.status("production-release", now=self.now, binding=self.binding)
        self.assertEqual(status["status"], "APPROVED")
        self.record(restored, "user:bob", "security-reviewer", "REVOKE")
        status = restored.status("production-release", now=self.now, binding=self.binding)
        self.assertEqual(status["status"], "PENDING")

    def test_every_receipt_identity_field_and_role_are_enforced(self) -> None:
        for field in self.binding:
            with self.subTest(field=field):
                ledger = ApprovalLedger.from_dict(self.document)
                wrong = {**self.binding, field: "d" * 64 if "Digest" in field else "wrong-id"}
                with self.assertRaisesRegex(WorkflowError, field):
                    ledger.record(
                        "production-release", "user:alice", "release-manager", "GRANT",
                        "c" * 64, wrong, now=self.now,
                    )
        ledger = ApprovalLedger.from_dict(self.document)
        with self.assertRaisesRegex(WorkflowError, "approverRole"):
            ledger.record(
                "production-release", "user:alice", "security-reviewer", "GRANT",
                "c" * 64, self.binding, now=self.now,
            )

    def test_expired_future_retrograde_and_non_monotonic_events_fail_closed(self) -> None:
        ledger = ApprovalLedger.from_dict(self.document)
        with self.assertRaisesRegex(WorkflowError, "future"):
            ledger.record(
                "production-release", "user:alice", "release-manager", "GRANT",
                "c" * 64, self.binding, now=self.now,
                occurred_at=self.now + timedelta(seconds=1),
            )
        self.record(ledger, "user:alice", "release-manager", "GRANT")
        with self.assertRaisesRegex(WorkflowError, "retrograde"):
            ledger.record(
                "production-release", "user:bob", "security-reviewer", "GRANT",
                "c" * 64, self.binding, now=self.now + timedelta(seconds=1),
                occurred_at=self.now,
            )
        expired = datetime(2026, 8, 10, tzinfo=UTC)
        with self.assertRaisesRegex(WorkflowError, "expiry"):
            ledger.record(
                "production-release", "user:bob", "security-reviewer", "GRANT",
                "c" * 64, self.binding, now=expired,
            )
        corrupted = copy.deepcopy(ledger.to_dict())
        corrupted["events"][0]["sequence"] = 2
        with self.assertRaisesRegex(WorkflowError, "sequence"):
            ApprovalLedger.from_dict(corrupted)

    def test_store_persists_validated_ledger_atomically(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "approvals.json"
            store = ApprovalStore(path)
            store.save(ApprovalLedger.from_dict(self.document))
            store.record(
                "production-release", "user:alice", "release-manager", "GRANT",
                "c" * 64, self.binding, now=self.now,
            )
            restored = store.load()
            self.assertEqual(len(restored.events), 1)
            self.assertTrue(path.exists())
            self.assertTrue(path.with_name("approvals.json.lock").exists())

    def test_trusted_keyring_requires_and_verifies_identity_bound_signatures(self) -> None:
        keys = {
            "user:alice": {"alice-2026": b"a" * 32},
            "user:bob": {"bob-2026": b"b" * 32},
        }
        ledger = ApprovalLedger.from_dict(self.document, trusted_keys=keys)
        with self.assertRaisesRegex(WorkflowError, "trusted signature"):
            self.record(ledger, "user:alice", "release-manager", "GRANT")
        event = ledger.record(
            "production-release",
            "user:alice",
            "release-manager",
            "GRANT",
            "c" * 64,
            self.binding,
            now=self.now,
            signing_key=keys["user:alice"]["alice-2026"],
            key_id="alice-2026",
        )
        self.assertEqual(event["signature"]["algorithm"], "hmac-sha256")
        restored = ApprovalLedger.from_dict(ledger.to_dict(), trusted_keys=keys)
        self.assertEqual(restored.events[0]["identity"], "user:alice")

        tampered = copy.deepcopy(ledger.to_dict())
        tampered["events"][0]["evidenceDigest"] = "d" * 64
        payload = {
            key: value
            for key, value in tampered["events"][0].items()
            if key != "eventDigest"
        }
        tampered["events"][0]["eventDigest"] = hashlib.sha256(
            json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest()
        with self.assertRaisesRegex(WorkflowError, "signature verification"):
            ApprovalLedger.from_dict(tampered, trusted_keys=keys)

        wrong_identity_keys = {"user:alice": {"alice-2026": b"z" * 32}}
        with self.assertRaisesRegex(WorkflowError, "signature verification"):
            ApprovalLedger.from_dict(ledger.to_dict(), trusted_keys=wrong_identity_keys)


class PortfolioTests(unittest.TestCase):
    def setUp(self) -> None:
        self.features = [
            self.feature("core"),
            self.feature("dependent", depends_on=["core"]),
            self.feature("independent"),
            self.feature("optional", required=False),
        ]
        self.portfolio = {"schemaVersion": 2, "maxConcurrency": 2, "features": self.features}

    @staticmethod
    def feature(
        feature_id: str, *, depends_on: list[str] | None = None, required: bool = True
    ) -> dict[str, object]:
        return {
            "id": feature_id,
            "workflowId": f"{feature_id}-flow",
            "graphDigest": hashlib.sha256(feature_id.encode()).hexdigest(),
            "executionId": f"{feature_id}-execution",
            "dependsOn": depends_on or [],
            "required": required,
        }

    def observed(
        self, feature_id: str, status: str, verification: str = "PENDING"
    ) -> dict[str, str]:
        feature = next(item for item in self.features if item["id"] == feature_id)
        return {
            "workflowId": str(feature["workflowId"]),
            "graphDigest": str(feature["graphDigest"]),
            "executionId": str(feature["executionId"]),
            "status": status,
            "verificationStatus": verification,
        }

    def test_failure_is_contained_and_concurrency_defers_independent_work(self) -> None:
        result = orchestrate_portfolio(
            self.portfolio, {"core": self.observed("core", "FAILED", "FAIL")}
        )
        self.assertEqual(result["status"], "FAILED")
        self.assertEqual(result["blockedBy"], {"dependent": ["core"]})
        self.assertEqual(result["ready"], ["independent", "optional"])
        limited = orchestrate_portfolio(
            {**self.portfolio, "maxConcurrency": 1},
            {"core": self.observed("core", "RUNNING")},
        )
        self.assertEqual(limited["ready"], [])
        self.assertEqual(limited["deferred"], ["independent", "optional"])

    def test_done_requires_pass_and_observed_identity_must_match(self) -> None:
        unverified = orchestrate_portfolio(
            self.portfolio, {"core": self.observed("core", "DONE", "PENDING")}
        )
        self.assertEqual(unverified["statuses"]["core"], "UNVERIFIED")
        self.assertEqual(unverified["blockedBy"], {"dependent": ["core"]})
        mismatch = self.observed("core", "DONE", "PASS")
        mismatch["executionId"] = "other-execution"
        with self.assertRaisesRegex(WorkflowError, "executionId identity mismatch"):
            orchestrate_portfolio(self.portfolio, {"core": mismatch})

    def test_verified_truthful_rollup_and_cycle_rejection(self) -> None:
        observed = {
            item["id"]: self.observed(str(item["id"]), "DONE", "PASS")
            for item in self.features
            if item["required"]
        }
        result = orchestrate_portfolio(self.portfolio, observed)
        self.assertEqual(result["status"], "DONE")
        cyclic = {
            "schemaVersion": 2,
            "maxConcurrency": 1,
            "features": [self.feature("a", depends_on=["b"]), self.feature("b", depends_on=["a"])],
        }
        with self.assertRaisesRegex(WorkflowError, "cycle"):
            orchestrate_portfolio(cyclic, {})


if __name__ == "__main__":
    unittest.main()
