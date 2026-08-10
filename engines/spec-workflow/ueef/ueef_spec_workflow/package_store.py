"""Verified, versioned package store with atomic activation and rollback."""

from __future__ import annotations

import hashlib
import hmac
import json
import os
import re
import shutil
import time
import uuid
from collections.abc import Iterator
from contextlib import contextmanager
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from .errors import WorkflowError
from .template_composition import Composition, compose_templates, materialize_composition

_IDENTIFIER = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
_SHA256 = re.compile(r"^[0-9a-f]{64}$")
_VERSION = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
_SAFE_PERMISSIONS = frozenset({"read", "write-owned", "test", "verify"})
_ATTESTATION_DOMAIN = "ueef-package-provenance-v1"


def _is_link_like(path: Path) -> bool:
    is_junction = getattr(os.path, "isjunction", None)
    return path.is_symlink() or bool(is_junction and is_junction(path))


def _regular_payload_files(root: Path) -> dict[str, Path]:
    """Walk payload without following symlinks, junctions, or special entries."""

    observed: dict[str, Path] = {}

    def visit(directory: Path) -> None:
        if _is_link_like(directory):
            raise WorkflowError("installed package payload contains a link-like directory")
        with os.scandir(directory) as entries:
            for entry in entries:
                candidate = Path(entry.path)
                if _is_link_like(candidate):
                    raise WorkflowError("installed package payload contains a link-like entry")
                if entry.is_dir(follow_symlinks=False):
                    visit(candidate)
                elif entry.is_file(follow_symlinks=False):
                    observed[candidate.relative_to(root).as_posix()] = candidate
                else:
                    raise WorkflowError("installed package payload contains a special entry")

    visit(root)
    return observed


def _default_metadata(
    name: str,
    version: str,
    composition_digest: str,
    *,
    engine_schema: int,
    engine_version: str,
    authority_digest: str,
    source: str,
) -> dict[str, Any]:
    """Build a least-authority metadata envelope for compatibility callers."""

    return {
        "schemaVersion": 1,
        "identity": {
            "name": name,
            "version": version,
            "compositionDigest": composition_digest,
        },
        "provenance": {"source": source, "digest": composition_digest},
        "compatibility": {
            "engineSchema": engine_schema,
            "engineVersionRange": f"=={engine_version}",
        },
        "policy": {"authorityDigest": authority_digest, "permissions": []},
    }


def _canonical(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")


def _parse_time(value: object, label: str) -> datetime:
    if not isinstance(value, str):
        raise WorkflowError(f"package attestation {label} is required")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise WorkflowError(f"package attestation {label} is invalid") from exc
    if parsed.tzinfo is None:
        raise WorkflowError(f"package attestation {label} must include a timezone")
    return parsed.astimezone(UTC)


def _attestation_statement(metadata: dict[str, Any]) -> dict[str, Any]:
    provenance = metadata["provenance"]
    attestation = provenance["attestation"]
    return {
        "domain": _ATTESTATION_DOMAIN,
        "identity": metadata["identity"],
        "source": provenance["source"],
        "sourceDigest": provenance["digest"],
        "compatibility": metadata["compatibility"],
        "policy": metadata["policy"],
        "signerId": attestation["signerId"],
        "keyId": attestation["keyId"],
        "sequence": attestation["sequence"],
        "issuedAt": attestation["issuedAt"],
        "expiresAt": attestation["expiresAt"],
    }


def sign_package_metadata(
    metadata: dict[str, Any],
    *,
    signer_id: str,
    key_id: str,
    signing_key: bytes,
    sequence: int,
    issued_at: datetime,
    expires_at: datetime,
) -> dict[str, Any]:
    """Return identity-bound provenance signed by a separately managed trusted key."""

    _validate_identifier(signer_id, "signer identity")
    _validate_identifier(key_id, "signer key ID")
    if not isinstance(signing_key, bytes) or len(signing_key) < 32:
        raise WorkflowError("package signing key must contain at least 256 bits")
    if isinstance(sequence, bool) or not isinstance(sequence, int) or sequence < 1:
        raise WorkflowError("package attestation sequence must be positive")
    if issued_at.tzinfo is None or expires_at.tzinfo is None or expires_at <= issued_at:
        raise WorkflowError("package attestation validity interval is invalid")
    result = json.loads(json.dumps(metadata))
    result["schemaVersion"] = 2
    policy = result.get("policy")
    if isinstance(policy, dict) and isinstance(policy.get("permissions"), list):
        policy["permissions"] = sorted({str(item).casefold() for item in policy["permissions"]})
    provenance = result.get("provenance")
    if not isinstance(provenance, dict):
        raise WorkflowError("package provenance metadata is required")
    provenance["attestation"] = {
        "signerId": signer_id,
        "keyId": key_id,
        "sequence": sequence,
        "issuedAt": issued_at.astimezone(UTC).isoformat().replace("+00:00", "Z"),
        "expiresAt": expires_at.astimezone(UTC).isoformat().replace("+00:00", "Z"),
        "algorithm": "hmac-sha256",
    }
    provenance["attestation"]["signature"] = hmac.new(
        signing_key, _canonical(_attestation_statement(result)), hashlib.sha256
    ).hexdigest()
    return result


def _validate_identifier(value: str, label: str) -> None:
    if not isinstance(value, str) or not _IDENTIFIER.fullmatch(value):
        raise WorkflowError(f"invalid package {label}")


def _version_tuple(value: str) -> tuple[int, int, int]:
    match = _VERSION.fullmatch(value)
    if not match:
        raise WorkflowError("invalid semantic engine version")
    return tuple(int(part) for part in match.groups())  # type: ignore[return-value]


def _version_matches(version: str, expression: object) -> bool:
    current = _version_tuple(version)
    if not isinstance(expression, str) or not expression:
        raise WorkflowError("package compatibility range is invalid")
    for clause in expression.split(","):
        clause = clause.strip()
        match = re.fullmatch(r"(>=|<=|>|<|==)(\d+\.\d+\.\d+)", clause)
        if not match:
            raise WorkflowError("package compatibility range is invalid")
        operator, raw_target = match.groups()
        target = _version_tuple(raw_target)
        accepted = {
            ">=": current >= target,
            "<=": current <= target,
            ">": current > target,
            "<": current < target,
            "==": current == target,
        }[operator]
        if not accepted:
            return False
    return True


def _validate_metadata(
    metadata: object,
    *,
    name: str,
    version: str,
    composition_digest: str,
    engine_schema: int,
    engine_version: str,
    authority_digest: str,
    allowed_permissions: frozenset[str],
    trusted_signers: dict[str, dict[str, bytes]],
    require_attestation: bool,
    now: datetime,
) -> dict[str, Any]:
    if not isinstance(metadata, dict) or metadata.get("schemaVersion") not in {1, 2}:
        raise WorkflowError("package metadata schemaVersion must be 1 or 2")
    identity = metadata.get("identity")
    provenance = metadata.get("provenance")
    compatibility = metadata.get("compatibility")
    policy = metadata.get("policy")
    if identity != {"name": name, "version": version, "compositionDigest": composition_digest}:
        raise WorkflowError("package metadata identity does not match package content")
    if not isinstance(provenance, dict):
        raise WorkflowError("package provenance metadata is required")
    source = provenance.get("source")
    provenance_digest = provenance.get("digest")
    if not isinstance(source, str) or not source.strip() or not _SHA256.fullmatch(
        provenance_digest if isinstance(provenance_digest, str) else ""
    ):
        raise WorkflowError("package provenance source and digest are invalid")
    if not isinstance(compatibility, dict) or compatibility.get("engineSchema") != engine_schema:
        raise WorkflowError("package engine schema is incompatible")
    engine_range = compatibility.get("engineVersionRange")
    if not _version_matches(engine_version, engine_range):
        raise WorkflowError("package engine version is incompatible")
    if not isinstance(policy, dict) or policy.get("authorityDigest") != authority_digest:
        raise WorkflowError("package policy authority does not match current authority")
    permissions = policy.get("permissions")
    if not isinstance(permissions, list) or any(not isinstance(item, str) for item in permissions):
        raise WorkflowError("package policy permissions must be strings")
    normalized_permissions = frozenset(item.casefold() for item in permissions)
    if not normalized_permissions.issubset(allowed_permissions):
        raise WorkflowError("package policy attempts to widen permissions")
    normalized = {
        "schemaVersion": metadata["schemaVersion"],
        "identity": identity,
        "provenance": {"source": source, "digest": provenance_digest},
        "compatibility": {
            "engineSchema": engine_schema,
            "engineVersionRange": engine_range,
        },
        "policy": {
            "authorityDigest": authority_digest,
            "permissions": sorted(normalized_permissions),
        },
    }
    attestation = provenance.get("attestation")
    if metadata["schemaVersion"] == 1:
        if require_attestation:
            raise WorkflowError("trusted package provenance attestation is required")
    else:
        if not isinstance(attestation, dict):
            raise WorkflowError("trusted package provenance attestation is required")
        signer_id, key_id = attestation.get("signerId"), attestation.get("keyId")
        if not isinstance(signer_id, str) or not isinstance(key_id, str):
            raise WorkflowError("package attestation signer identity is invalid")
        key = trusted_signers.get(signer_id, {}).get(key_id)
        if not isinstance(key, bytes) or len(key) < 32:
            raise WorkflowError("package attestation signer is not trusted")
        sequence = attestation.get("sequence")
        if isinstance(sequence, bool) or not isinstance(sequence, int) or sequence < 1:
            raise WorkflowError("package attestation sequence must be positive")
        issued = _parse_time(attestation.get("issuedAt"), "issuedAt")
        expires = _parse_time(attestation.get("expiresAt"), "expiresAt")
        if issued > now.astimezone(UTC) or expires <= now.astimezone(UTC) or expires <= issued:
            raise WorkflowError("package attestation is not currently valid")
        if attestation.get("algorithm") != "hmac-sha256":
            raise WorkflowError("package attestation algorithm is unsupported")
        signature = attestation.get("signature")
        if not isinstance(signature, str) or not _SHA256.fullmatch(signature):
            raise WorkflowError("package attestation signature is invalid")
        normalized["provenance"]["attestation"] = dict(attestation)
        expected = hmac.new(
            key, _canonical(_attestation_statement(normalized)), hashlib.sha256
        ).hexdigest()
        if not hmac.compare_digest(signature, expected):
            raise WorkflowError("package attestation signature verification failed")
    return {**normalized, "metadataDigest": hashlib.sha256(_canonical(normalized)).hexdigest()}


def _fsync_directory(path: Path) -> None:
    if os.name == "nt":
        return
    descriptor = os.open(path, os.O_RDONLY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def _write_json_atomic(path: Path, value: object) -> None:
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    try:
        with temporary.open("wb") as handle:
            handle.write(_canonical(value))
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
        _fsync_directory(path.parent)
    finally:
        temporary.unlink(missing_ok=True)


@contextmanager
def _exclusive_file_lock(path: Path, timeout_seconds: float = 5.0) -> Iterator[None]:
    """Acquire a bounded cross-process advisory lock for pointer transactions."""

    with path.open("a+b") as handle:
        if handle.seek(0, os.SEEK_END) == 0:
            handle.write(b"\0")
            handle.flush()
            os.fsync(handle.fileno())
        deadline = time.monotonic() + timeout_seconds
        while True:
            try:
                handle.seek(0)
                if os.name == "nt":
                    import msvcrt

                    msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
                else:
                    import fcntl

                    fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except OSError as exc:
                if time.monotonic() >= deadline:
                    raise WorkflowError("timed out waiting for package pointer lock") from exc
                time.sleep(0.05)
        try:
            yield
        finally:
            handle.seek(0)
            if os.name == "nt":
                import msvcrt

                msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                import fcntl

                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


class PackageStore:
    """A filesystem store where installed versions are immutable after verification."""

    def __init__(
        self,
        root: Path,
        *,
        engine_schema: int = 1,
        engine_version: str = "0.1.0",
        authority_digest: str = "0" * 64,
        allowed_permissions: frozenset[str] = _SAFE_PERMISSIONS,
        trusted_signers: dict[str, dict[str, bytes]] | None = None,
        require_attestation: bool | None = None,
        now: datetime | None = None,
    ) -> None:
        self.root = Path(root)
        if (
            isinstance(engine_schema, bool)
            or not isinstance(engine_schema, int)
            or engine_schema < 1
        ):
            raise WorkflowError("engine schema must be a positive integer")
        _version_tuple(engine_version)
        if not _SHA256.fullmatch(authority_digest):
            raise WorkflowError("authority digest must be lowercase SHA-256")
        self.engine_schema = engine_schema
        self.engine_version = engine_version
        self.authority_digest = authority_digest
        self.allowed_permissions = allowed_permissions
        self.trusted_signers = trusted_signers or {}
        self.require_attestation = (
            bool(self.trusted_signers) if require_attestation is None else require_attestation
        )
        self.now = now
        self.packages = self.root / "packages"
        self.staging = self.root / ".staging"
        self.active = self.root / "active"
        self.trust = self.root / "trust"
        for directory in (self.packages, self.staging, self.active, self.trust):
            directory.mkdir(parents=True, exist_ok=True)

    def install(
        self,
        name: str,
        version: str,
        source: Path,
        *,
        metadata: object | None = None,
        expected_digest: str | None = None,
    ) -> dict[str, Any]:
        composition = compose_templates({"core": Path(source)})
        if metadata is None:
            metadata = _default_metadata(
                name,
                version,
                composition.digest,
                engine_schema=self.engine_schema,
                engine_version=self.engine_version,
                authority_digest=self.authority_digest,
                source=str(Path(source).resolve()),
            )
        return self.install_composition(
            name,
            version,
            composition,
            metadata=metadata,
            expected_digest=expected_digest,
        )

    def install_composition(
        self,
        name: str,
        version: str,
        composition: Composition,
        *,
        metadata: object | None = None,
        expected_digest: str | None = None,
    ) -> dict[str, Any]:
        """Verify and install an already composed multi-layer package."""

        _validate_identifier(name, "name")
        _validate_identifier(version, "version")
        if expected_digest is not None and composition.digest != expected_digest:
            raise WorkflowError("package digest does not match expected digest")
        if metadata is None:
            metadata = _default_metadata(
                name,
                version,
                composition.digest,
                engine_schema=self.engine_schema,
                engine_version=self.engine_version,
                authority_digest=self.authority_digest,
                source=f"composition:{composition.digest}",
            )
        normalized_metadata = _validate_metadata(
            metadata,
            name=name,
            version=version,
            composition_digest=composition.digest,
            engine_schema=self.engine_schema,
            engine_version=self.engine_version,
            authority_digest=self.authority_digest,
            allowed_permissions=self.allowed_permissions,
            trusted_signers=self.trusted_signers,
            require_attestation=self.require_attestation,
            now=self.now or datetime.now(UTC),
        )

        destination = self.packages / name / version / composition.digest
        if destination.exists():
            self._verify_installed(destination, composition.digest)
            self._verify_metadata(
                destination, name=name, version=version, digest=composition.digest
            )
            self._accept_attestation(name, normalized_metadata)
            return self._receipt(name, version, composition.digest, destination, False)

        stage = self.staging / f"{name}-{version}-{uuid.uuid4().hex}"
        try:
            materialize_composition(composition, stage)
            (stage / "package-metadata.json").write_bytes(_canonical(normalized_metadata))
            self._verify_installed(stage, composition.digest)
            self._verify_metadata(stage, name=name, version=version, digest=composition.digest)
            destination.parent.mkdir(parents=True, exist_ok=True)
            with _exclusive_file_lock(self.trust / f"{name}.lock"):
                os.replace(stage, destination)
                self._accept_attestation_unlocked(name, normalized_metadata)
        finally:
            if stage.exists():
                shutil.rmtree(stage)
        return self._receipt(name, version, composition.digest, destination, True)

    def activate(self, name: str, version: str, digest: str) -> dict[str, Any]:
        _validate_identifier(name, "name")
        _validate_identifier(version, "version")
        if not isinstance(digest, str) or not _SHA256.fullmatch(digest):
            raise WorkflowError("invalid package digest; expected lowercase SHA-256")
        destination = self.packages / name / version / digest
        self._verify_installed(destination, digest)
        self._verify_metadata(destination, name=name, version=version, digest=digest)
        with _exclusive_file_lock(self.active / f"{name}.lock"):
            pointer = self._read_pointer(name)
            previous = pointer.get("current") if pointer else None
            history = list(pointer.get("history", [])) if pointer else []
            journal = list(pointer.get("rollbackJournal", [])) if pointer else []
            current = {"version": version, "digest": digest}
            if previous and previous != current:
                history.append(previous)
                journal.append({"operation": "ACTIVATE", "from": previous, "to": current})
            value = {
                "schemaVersion": 1,
                "name": name,
                "current": current,
                "history": history[-32:],
                "rollbackJournal": journal[-64:],
            }
            _write_json_atomic(self.active / f"{name}.json", value)
            return value

    def rollback(self, name: str) -> dict[str, Any]:
        _validate_identifier(name, "name")
        with _exclusive_file_lock(self.active / f"{name}.lock"):
            pointer = self._read_pointer(name)
            if not pointer or not pointer.get("history"):
                raise WorkflowError("package has no rollback target")
            history = list(pointer["history"])
            target = history.pop()
            destination = self.packages / name / target["version"] / target["digest"]
            self._verify_installed(destination, target["digest"])
            self._verify_metadata(
                destination,
                name=name,
                version=target["version"],
                digest=target["digest"],
            )
            current = pointer["current"]
            history.append(current)
            journal = list(pointer.get("rollbackJournal", []))
            journal.append({"operation": "ROLLBACK", "from": current, "to": target})
            value = {
                "schemaVersion": 1,
                "name": name,
                "current": target,
                "history": history[-32:],
                "rollbackJournal": journal[-64:],
            }
            _write_json_atomic(self.active / f"{name}.json", value)
            return value

    def _read_pointer(self, name: str) -> dict[str, Any] | None:
        path = self.active / f"{name}.json"
        if not path.exists():
            return None
        value = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(value, dict) or value.get("schemaVersion") != 1:
            raise WorkflowError("active package pointer is invalid")
        return value

    def _verify_metadata(self, directory: Path, *, name: str, version: str, digest: str) -> None:
        path = directory / "package-metadata.json"
        if not path.is_file() or _is_link_like(path):
            raise WorkflowError("installed package metadata is missing")
        try:
            metadata = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            raise WorkflowError("installed package metadata is invalid") from exc
        claimed_digest = (
            metadata.pop("metadataDigest", None) if isinstance(metadata, dict) else None
        )
        if claimed_digest != hashlib.sha256(_canonical(metadata)).hexdigest():
            raise WorkflowError("installed package metadata digest is invalid")
        _validate_metadata(
            metadata,
            name=name,
            version=version,
            composition_digest=digest,
            engine_schema=self.engine_schema,
            engine_version=self.engine_version,
            authority_digest=self.authority_digest,
            allowed_permissions=self.allowed_permissions,
            trusted_signers=self.trusted_signers,
            require_attestation=self.require_attestation,
            now=self.now or datetime.now(UTC),
        )

    def _accept_attestation(self, name: str, metadata: dict[str, Any]) -> None:
        with _exclusive_file_lock(self.trust / f"{name}.lock"):
            self._accept_attestation_unlocked(name, metadata)

    def _accept_attestation_unlocked(self, name: str, metadata: dict[str, Any]) -> None:
        if metadata.get("schemaVersion") != 2:
            return
        attestation = metadata["provenance"]["attestation"]
        signer_id = attestation["signerId"]
        fingerprint = hashlib.sha256(_canonical(_attestation_statement(metadata))).hexdigest()
        path = self.trust / f"{name}.json"
        state: dict[str, Any] = {"schemaVersion": 1, "name": name, "signers": {}}
        if path.exists():
            try:
                loaded = json.loads(path.read_text(encoding="utf-8"))
            except json.JSONDecodeError as exc:
                raise WorkflowError("package trust watermark is invalid") from exc
            if not isinstance(loaded, dict) or loaded.get("schemaVersion") != 1:
                raise WorkflowError("package trust watermark is invalid")
            state = loaded
        signers = state.get("signers")
        if not isinstance(signers, dict):
            raise WorkflowError("package trust watermark is invalid")
        previous = signers.get(signer_id)
        sequence = attestation["sequence"]
        if previous:
            if not isinstance(previous, dict):
                raise WorkflowError("package trust watermark is invalid")
            highest = previous.get("highestSequence")
            if not isinstance(highest, int):
                raise WorkflowError("package trust watermark is invalid")
            if sequence < highest:
                raise WorkflowError("package attestation rollback was rejected")
            if sequence == highest and previous.get("fingerprint") != fingerprint:
                raise WorkflowError("package attestation sequence equivocation was rejected")
        signers[signer_id] = {
            "keyId": attestation["keyId"],
            "highestSequence": sequence,
            "fingerprint": fingerprint,
            "expiresAt": attestation["expiresAt"],
        }
        _write_json_atomic(path, state)

    @staticmethod
    def _verify_installed(directory: Path, expected_digest: str) -> None:
        if not directory.is_dir() or _is_link_like(directory):
            raise WorkflowError("package version is not installed")
        manifest_path = directory / "manifest.json"
        payload = directory / "payload"
        if (
            not manifest_path.is_file()
            or _is_link_like(manifest_path)
            or not payload.is_dir()
            or _is_link_like(payload)
        ):
            raise WorkflowError("installed package structure is invalid")
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        claimed = manifest.pop("digest", None)
        actual = hashlib.sha256(_canonical(manifest)).hexdigest()
        if claimed != expected_digest or actual != expected_digest:
            raise WorkflowError("installed package manifest digest is invalid")
        observed_files = _regular_payload_files(payload)
        expected_paths: set[str] = set()
        for item in manifest.get("files", []):
            relative = item["path"]
            expected_paths.add(relative)
            candidate = observed_files.get(relative)
            if candidate is None:
                raise WorkflowError("installed package payload is incomplete")
            content = candidate.read_bytes()
            content_digest = hashlib.sha256(content).hexdigest()
            if len(content) != item["size"] or content_digest != item["sha256"]:
                raise WorkflowError("installed package payload digest is invalid")
        if set(observed_files) != expected_paths:
            raise WorkflowError("installed package payload contains untracked files")

    @staticmethod
    def _receipt(
        name: str, version: str, digest: str, path: Path, installed: bool
    ) -> dict[str, Any]:
        return {
            "schemaVersion": 1,
            "name": name,
            "version": version,
            "digest": digest,
            "path": str(path),
            "installed": installed,
            "verified": True,
        }
