"""Provenance and safe validation bridge for the unmodified Spec Kit snapshot."""

from __future__ import annotations

import hashlib
import importlib
import json
import sys
from collections.abc import Iterable
from pathlib import Path
from typing import Any

from .errors import UpstreamDependencyError, WorkflowError


def engine_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _metadata() -> dict[str, Any]:
    path = engine_root() / "UPSTREAM.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise WorkflowError(f"cannot read upstream metadata: {exc}") from exc
    if not isinstance(data, dict):
        raise WorkflowError("UPSTREAM.json must contain an object")
    return data


def _snapshot_files(snapshot: Path) -> Iterable[Path]:
    for relative in ("LICENSE", "README.upstream.md", "pyproject.upstream.toml"):
        yield snapshot / relative
    yield from sorted((snapshot / "src").rglob("*"))
    yield snapshot / "workflows" / "speckit" / "workflow.yml"


def snapshot_aggregate(snapshot: Path) -> tuple[int, str]:
    files = sorted(
        (path for path in _snapshot_files(snapshot) if path.is_file()),
        key=lambda path: path.relative_to(snapshot).as_posix(),
    )
    digest = hashlib.sha256()
    for path in files:
        digest.update(path.relative_to(snapshot).as_posix().encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
    return len(files), digest.hexdigest()


def verify_snapshot() -> dict[str, Any]:
    metadata = _metadata()
    root = engine_root().resolve()
    snapshot = (root / str(metadata.get("snapshotPath", ""))).resolve()
    if root not in snapshot.parents:
        raise WorkflowError("upstream snapshotPath escapes the engine root")
    if not snapshot.is_dir():
        raise WorkflowError(f"upstream snapshot directory is missing: {snapshot}")
    count, aggregate = snapshot_aggregate(snapshot)
    expected_count = metadata.get("snapshotFileCount")
    expected_aggregate = metadata.get("snapshotAggregateSha256")
    valid = count == expected_count and aggregate == expected_aggregate
    return {
        "schemaVersion": 1,
        "valid": valid,
        "release": metadata.get("release"),
        "commit": metadata.get("commit"),
        "license": metadata.get("license"),
        "fileCount": count,
        "expectedFileCount": expected_count,
        "aggregateSha256": aggregate,
        "expectedAggregateSha256": expected_aggregate,
        "snapshotPath": str(snapshot),
    }


def _contains_shell_step(value: Any) -> bool:
    if isinstance(value, list):
        return any(_contains_shell_step(item) for item in value)
    if not isinstance(value, dict):
        return False
    if value.get("type") == "shell":
        return True
    return any(_contains_shell_step(item) for item in value.values())


def validate_workflow(path: str | Path, *, allow_shell: bool = False) -> dict[str, Any]:
    """Validate through upstream code but never execute the workflow."""

    snapshot_status = verify_snapshot()
    if not snapshot_status["valid"]:
        raise WorkflowError("upstream snapshot digest mismatch; refusing to load it")
    source_root = Path(snapshot_status["snapshotPath"]) / "src"
    loaded = sys.modules.get("specify_cli")
    if loaded is not None:
        loaded_path = Path(getattr(loaded, "__file__", "")).resolve()
        if source_root.resolve() not in loaded_path.parents:
            raise WorkflowError(f"a different specify_cli is already loaded from {loaded_path}")
    source_text = str(source_root)
    inserted = source_text not in sys.path
    if inserted:
        sys.path.insert(0, source_text)
    previous_dont_write_bytecode = sys.dont_write_bytecode
    sys.dont_write_bytecode = True
    try:
        try:
            module = importlib.import_module("specify_cli.workflows.engine")
        except ModuleNotFoundError as exc:
            dependency = exc.name or "unknown"
            raise UpstreamDependencyError(
                f"optional upstream dependency {dependency!r} is missing; "
                "install the engine's [upstream] extra"
            ) from exc
        definition = module.WorkflowDefinition.from_yaml(Path(path))
        errors = list(module.validate_workflow(definition))
        shell_present = _contains_shell_step(definition.steps)
        if shell_present and not allow_shell:
            errors.append("shell steps are denied by the UEEF validation boundary")
        return {
            "schemaVersion": 1,
            "valid": not errors,
            "workflowId": definition.id,
            "workflowVersion": definition.version,
            "shellStepsPresent": shell_present,
            "shellExecutionEnabled": False,
            "issues": errors,
            "upstream": snapshot_status,
        }
    finally:
        sys.dont_write_bytecode = previous_dont_write_bytecode
        if inserted:
            try:
                sys.path.remove(source_text)
            except ValueError:
                pass
