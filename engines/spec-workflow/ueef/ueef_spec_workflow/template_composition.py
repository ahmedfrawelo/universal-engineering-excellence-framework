"""Content-addressed, declarative template composition."""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import uuid
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from types import MappingProxyType

from .errors import WorkflowError

PRECEDENCE = ("core", "extension", "preset", "project")
DEFAULT_MAX_FILES = 4096
DEFAULT_MAX_FILE_BYTES = 4 * 1024 * 1024
DEFAULT_MAX_TOTAL_BYTES = 64 * 1024 * 1024
_EXECUTABLE_SUFFIXES = {
    ".bat", ".cmd", ".com", ".dll", ".exe", ".js", ".mjs", ".ps1", ".py", ".sh",
}


def _is_link_like(path: Path) -> bool:
    is_junction = getattr(os.path, "isjunction", None)
    return path.is_symlink() or bool(is_junction and is_junction(path))
_SAFE_PATH = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._/-]*$")


@dataclass(frozen=True)
class Composition:
    """An immutable composition result whose identity covers provenance and content."""

    manifest: Mapping[str, object]
    files: Mapping[str, bytes]
    digest: str


def _canonical(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")


def validate_template_path(value: str) -> PurePosixPath:
    """Validate a portable, relative declarative template path."""

    normalized = value.replace("\\", "/")
    path = PurePosixPath(normalized)
    if (
        not value
        or not _SAFE_PATH.fullmatch(normalized)
        or path.is_absolute()
        or ".." in path.parts
        or "." in path.parts
        or ":" in normalized
    ):
        raise WorkflowError(f"unsafe template path: {value!r}")
    if path.suffix.casefold() in _EXECUTABLE_SUFFIXES:
        raise WorkflowError(f"executable template content is forbidden: {value}")
    return path


def _assert_no_symlink(root: Path, candidate: Path) -> None:
    current = root
    if _is_link_like(current):
        raise WorkflowError(f"template source cannot be a symlink: {root}")
    for part in candidate.relative_to(root).parts:
        current = current / part
        if _is_link_like(current):
            raise WorkflowError(f"template source contains a symlink: {current}")


def compose_templates(
    sources: Mapping[str, Path],
    *,
    max_files: int = DEFAULT_MAX_FILES,
    max_file_bytes: int = DEFAULT_MAX_FILE_BYTES,
    max_total_bytes: int = DEFAULT_MAX_TOTAL_BYTES,
) -> Composition:
    """Overlay declarative template trees in core-to-project precedence order.

    The operation is read-only. Every selected file is copied to immutable bytes and the
    canonical manifest binds its path, winning layer, size, and content digest.
    """

    for label, limit in (
        ("max_files", max_files),
        ("max_file_bytes", max_file_bytes),
        ("max_total_bytes", max_total_bytes),
    ):
        if isinstance(limit, bool) or not isinstance(limit, int) or limit < 1:
            raise WorkflowError(f"{label} must be a positive integer")
    unknown = set(sources) - set(PRECEDENCE)
    if unknown:
        raise WorkflowError(f"unknown template source layers: {sorted(unknown)}")
    selected: dict[str, tuple[str, bytes]] = {}
    observed_files = 0
    observed_bytes = 0
    for layer in PRECEDENCE:
        if layer not in sources:
            continue
        root = Path(sources[layer])
        if not root.exists() or not root.is_dir() or _is_link_like(root):
            raise WorkflowError(f"template source must be a real directory: {root}")
        for candidate in sorted(root.rglob("*"), key=lambda item: item.as_posix()):
            _assert_no_symlink(root, candidate)
            if candidate.is_dir():
                continue
            if not candidate.is_file():
                raise WorkflowError(f"template source entry is not a regular file: {candidate}")
            observed_files += 1
            if observed_files > max_files:
                raise WorkflowError(f"template sources exceed the {max_files}-file limit")
            size = candidate.stat().st_size
            if size > max_file_bytes:
                raise WorkflowError(f"template file exceeds the {max_file_bytes}-byte limit")
            observed_bytes += size
            if observed_bytes > max_total_bytes:
                raise WorkflowError(f"template sources exceed the {max_total_bytes}-byte limit")
            relative = validate_template_path(candidate.relative_to(root).as_posix()).as_posix()
            if os.name != "nt" and candidate.stat().st_mode & 0o111:
                raise WorkflowError(f"executable template content is forbidden: {relative}")
            content = candidate.read_bytes()
            if content.startswith(b"#!"):
                raise WorkflowError(f"executable template content is forbidden: {relative}")
            selected[relative] = (layer, content)

    entries = [
        {
            "path": path,
            "source": layer,
            "size": len(content),
            "sha256": hashlib.sha256(content).hexdigest(),
        }
        for path, (layer, content) in sorted(selected.items())
    ]
    manifest_data: dict[str, object] = {
        "schemaVersion": 1,
        "precedence": list(reversed(PRECEDENCE)),
        "files": entries,
    }
    digest = hashlib.sha256(_canonical(manifest_data)).hexdigest()
    manifest = MappingProxyType({**manifest_data, "digest": digest})
    files = MappingProxyType({path: content for path, (_, content) in sorted(selected.items())})
    return Composition(manifest=manifest, files=files, digest=digest)


def materialize_composition(composition: Composition, destination: Path) -> Path:
    """Materialize an immutable composition through a verified atomic directory replace."""

    destination = Path(destination)
    parent = destination.parent
    if _is_link_like(parent):
        raise WorkflowError("composition destination parent cannot be a symlink")
    parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() or _is_link_like(destination):
        raise WorkflowError("composition destination already exists")
    stage = parent / f".{destination.name}.{uuid.uuid4().hex}.stage"
    stage.mkdir()
    try:
        payload = stage / "payload"
        payload.mkdir()
        for relative, content in composition.files.items():
            validated = validate_template_path(relative)
            target = payload.joinpath(*validated.parts)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
        (stage / "manifest.json").write_bytes(_canonical(dict(composition.manifest)))
        observed = compose_templates({"core": payload})
        if observed.files != composition.files:
            raise WorkflowError("materialized composition content verification failed")
        os.replace(stage, destination)
        return destination
    finally:
        if stage.exists():
            shutil.rmtree(stage)
