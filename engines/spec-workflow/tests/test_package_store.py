from __future__ import annotations

import json
import os
import subprocess
import tempfile
import threading
import unittest
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

from ueef_spec_workflow.errors import WorkflowError
from ueef_spec_workflow.package_store import PackageStore, sign_package_metadata
from ueef_spec_workflow.template_composition import compose_templates


def metadata(name: str, version: str, digest: str, **policy: object) -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "identity": {"name": name, "version": version, "compositionDigest": digest},
        "provenance": {"source": "repository://verified/templates", "digest": "a" * 64},
        "compatibility": {"engineSchema": 1, "engineVersionRange": ">=0.1.0,<1.0.0"},
        "policy": {
            "authorityDigest": "0" * 64,
            "permissions": ["read"],
            **policy,
        },
    }


def install(store: PackageStore, name: str, version: str, source: Path) -> dict[str, Any]:
    digest = compose_templates({"core": source}).digest
    return store.install(name, version, source, metadata=metadata(name, version, digest))


class PackageStoreTests(unittest.TestCase):
    def test_signed_provenance_rejects_tampering_untrusted_keys_expiry_and_rollback(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            now = datetime(2026, 8, 10, 12, tzinfo=UTC)
            keys = {"ueef-publisher": {"release-1": b"p" * 32}}
            store = PackageStore(root / "store", trusted_signers=keys, now=now)

            def signed(version: str, source: Path, sequence: int) -> dict[str, object]:
                digest = compose_templates({"core": source}).digest
                return sign_package_metadata(
                    metadata("workflow", version, digest),
                    signer_id="ueef-publisher",
                    key_id="release-1",
                    signing_key=keys["ueef-publisher"]["release-1"],
                    sequence=sequence,
                    issued_at=now - timedelta(minutes=5),
                    expires_at=now + timedelta(hours=1),
                )

            first = root / "first"
            second = root / "second"
            old = root / "old"
            for source, content in ((first, "one"), (second, "two"), (old, "old")):
                source.mkdir()
                (source / "template.md").write_text(content, encoding="utf-8")

            first_metadata = signed("1.0.0", first, 1)
            first_receipt = store.install("workflow", "1.0.0", first, metadata=first_metadata)
            self.assertTrue(first_receipt["verified"])
            store.activate("workflow", "1.0.0", str(first_receipt["digest"]))
            store.install("workflow", "2.0.0", second, metadata=signed("2.0.0", second, 2))
            with self.assertRaisesRegex(WorkflowError, "rollback"):
                store.install("workflow", "0.9.0", old, metadata=signed("0.9.0", old, 1))

            tampered = signed("3.0.0", old, 3)
            tampered["provenance"]["source"] = "repository://attacker"  # type: ignore[index]
            with self.assertRaisesRegex(WorkflowError, "signature verification"):
                store.install("workflow", "3.0.0", old, metadata=tampered)

            untrusted = PackageStore(
                root / "other", trusted_signers={"other": {"key": b"x" * 32}}, now=now
            )
            with self.assertRaisesRegex(WorkflowError, "not trusted"):
                untrusted.install("workflow", "1.0.0", first, metadata=first_metadata)

            expired_store = PackageStore(
                root / "store", trusted_signers=keys, now=now + timedelta(hours=2)
            )
            with self.assertRaisesRegex(WorkflowError, "not currently valid"):
                expired_store.activate(
                    "workflow", "1.0.0", str(first_receipt["digest"])
                )

    def test_trusted_store_rejects_unsigned_legacy_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            source.mkdir()
            (source / "template.md").write_text("safe", encoding="utf-8")
            digest = compose_templates({"core": source}).digest
            store = PackageStore(
                root / "store",
                trusted_signers={"ueef-publisher": {"release-1": b"p" * 32}},
            )
            with self.assertRaisesRegex(WorkflowError, "attestation is required"):
                store.install(
                    "workflow", "1.0.0", source,
                    metadata=metadata("workflow", "1.0.0", digest),
                )

    def test_install_activate_upgrade_and_rollback(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            store = PackageStore(root / "store")
            first_source = root / "first"
            second_source = root / "second"
            first_source.mkdir()
            second_source.mkdir()
            (first_source / "template.md").write_text("one", encoding="utf-8")
            (second_source / "template.md").write_text("two", encoding="utf-8")

            first = install(store, "workflow", "1.0.0", first_source)
            self.assertTrue(first["verified"])
            store.activate("workflow", "1.0.0", first["digest"])
            second = install(store, "workflow", "2.0.0", second_source)
            active = store.activate("workflow", "2.0.0", second["digest"])
            self.assertEqual(active["current"]["version"], "2.0.0")
            rolled_back = store.rollback("workflow")
            self.assertEqual(rolled_back["current"]["version"], "1.0.0")
            self.assertEqual(rolled_back["current"]["digest"], first["digest"])
            rolled_forward = store.rollback("workflow")
            self.assertEqual(rolled_forward["current"]["version"], "2.0.0")
            operations = [item["operation"] for item in rolled_forward["rollbackJournal"]]
            self.assertEqual(operations, ["ACTIVATE", "ROLLBACK", "ROLLBACK"])

    def test_failed_verification_never_installs_or_changes_active_pointer(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            store = PackageStore(root / "store")
            source = root / "source"
            source.mkdir()
            (source / "template.md").write_text("safe", encoding="utf-8")
            with self.assertRaisesRegex(WorkflowError, "expected digest"):
                store.install(
                    "workflow",
                    "1.0.0",
                    source,
                    metadata=metadata(
                        "workflow", "1.0.0", compose_templates({"core": source}).digest
                    ),
                    expected_digest="0" * 64,
                )
            self.assertFalse(any(store.packages.rglob("manifest.json")))
            self.assertFalse((store.active / "workflow.json").exists())

    def test_tampered_installed_version_cannot_be_activated(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            store = PackageStore(root / "store")
            source = root / "source"
            source.mkdir()
            (source / "template.md").write_text("safe", encoding="utf-8")
            receipt = install(store, "workflow", "1.0.0", source)
            (Path(receipt["path"]) / "payload" / "template.md").write_text(
                "tampered", encoding="utf-8"
            )
            with self.assertRaisesRegex(WorkflowError, "payload digest"):
                store.activate("workflow", "1.0.0", receipt["digest"])

    def test_link_like_payload_entry_cannot_escape_store_during_activation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            store = PackageStore(root / "store")
            source = root / "source"
            source.mkdir()
            (source / "template.md").write_text("safe", encoding="utf-8")
            receipt = install(store, "workflow", "1.0.0", source)
            external = root / "external"
            external.mkdir()
            (external / "secret.md").write_text("outside", encoding="utf-8")
            link = Path(receipt["path"]) / "payload" / "escape"
            if os.name == "nt":
                created = subprocess.run(
                    ["cmd", "/d", "/c", "mklink", "/J", str(link), str(external)],
                    capture_output=True,
                    check=False,
                    text=True,
                )
                self.assertEqual(created.returncode, 0, created.stderr or created.stdout)
            else:
                link.symlink_to(external, target_is_directory=True)
            with self.assertRaisesRegex(WorkflowError, "link-like"):
                store.activate("workflow", "1.0.0", receipt["digest"])

    def test_rejects_non_sha256_digest_and_serializes_concurrent_activations(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            store = PackageStore(root / "store")
            receipts = []
            for number in range(3):
                source = root / f"source-{number}"
                source.mkdir()
                (source / "template.md").write_text(str(number), encoding="utf-8")
                receipts.append(install(store, "workflow", f"{number}.0.0", source))
            with self.assertRaisesRegex(WorkflowError, "lowercase SHA-256"):
                store.activate("workflow", "0.0.0", receipts[0]["digest"].upper())
            store.activate("workflow", "0.0.0", receipts[0]["digest"])
            barrier = threading.Barrier(2)
            errors: list[BaseException] = []

            def activate(index: int) -> None:
                try:
                    barrier.wait()
                    store.activate("workflow", f"{index}.0.0", receipts[index]["digest"])
                except BaseException as exc:
                    errors.append(exc)

            workers = [threading.Thread(target=activate, args=(index,)) for index in (1, 2)]
            for worker in workers:
                worker.start()
            for worker in workers:
                worker.join()
            self.assertEqual(errors, [])
            pointer = store._read_pointer("workflow")
            self.assertIsNotNone(pointer)
            assert pointer is not None
            self.assertEqual(len(pointer["rollbackJournal"]), 2)
            self.assertEqual(len(pointer["history"]), 2)

    def test_install_composition_validates_compatibility_and_policy_authority(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            core = root / "core"
            project = root / "project"
            core.mkdir()
            project.mkdir()
            (core / "template.md").write_text("core", encoding="utf-8")
            (project / "template.md").write_text("project", encoding="utf-8")
            composition = compose_templates({"core": core, "project": project})
            store = PackageStore(root / "store")
            package_metadata = metadata("workflow", "1.0.0", composition.digest)
            receipt = store.install_composition(
                "workflow", "1.0.0", composition, metadata=package_metadata
            )
            self.assertTrue(receipt["verified"])
            bad_compatibility = {
                **metadata("workflow", "2.0.0", composition.digest),
                "compatibility": {"engineSchema": 2, "engineVersionRange": ">=2.0.0"},
            }
            with self.assertRaisesRegex(WorkflowError, "schema is incompatible"):
                store.install_composition(
                    "workflow", "2.0.0", composition, metadata=bad_compatibility
                )
            widened = metadata(
                "workflow", "2.0.0", composition.digest, permissions=["write-anywhere"]
            )
            with self.assertRaisesRegex(WorkflowError, "widen permissions"):
                store.install_composition("workflow", "2.0.0", composition, metadata=widened)

    def test_activation_revalidates_tampered_metadata_and_current_authority(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            source.mkdir()
            (source / "template.md").write_text("safe", encoding="utf-8")
            store = PackageStore(root / "store")
            receipt = install(store, "workflow", "1.0.0", source)
            metadata_path = Path(str(receipt["path"])) / "package-metadata.json"
            original = metadata_path.read_text(encoding="utf-8")
            document = json.loads(original)
            document["policy"]["permissions"] = ["write-anywhere"]
            metadata_path.write_text(json.dumps(document), encoding="utf-8")
            with self.assertRaisesRegex(WorkflowError, "metadata digest"):
                store.activate("workflow", "1.0.0", str(receipt["digest"]))

            metadata_path.write_text(original, encoding="utf-8")
            different_authority = PackageStore(root / "store", authority_digest="b" * 64)
            with self.assertRaisesRegex(WorkflowError, "authority"):
                different_authority.activate(
                    "workflow", "1.0.0", str(receipt["digest"])
                )


if __name__ == "__main__":
    unittest.main()
