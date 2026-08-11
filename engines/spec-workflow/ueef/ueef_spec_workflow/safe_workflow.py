"""Fail-closed expansion of bounded declarative Spec Kit workflow constructs."""

from __future__ import annotations

import copy
import hashlib
import json
import re
from typing import Any

from .errors import WorkflowError

_MAX_STEPS = 500
_MAX_LOOP = 20
_MAX_OVERLAYS = 64
_MAX_EDITS = 100
_MAX_DOCUMENT_BYTES = 1024 * 1024
_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
_WORKFLOW_ID = re.compile(r"^[a-z0-9](?:[a-z0-9-]{0,126}[a-z0-9])?$")
_SEMVER = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")
_SOURCE_RANK = {"core": 0, "extension": 1, "preset": 2, "project": 3}
_STEP_FIELDS = {
    "task": frozenset({"type", "id", "title"}),
    "if": frozenset({"type", "condition", "then", "else"}),
    "fan-out": frozenset({"type", "branches"}),
    "fan-in": frozenset({"type", "id"}),
    "while": frozenset({"type", "condition", "maxIterations", "steps"}),
    "do-while": frozenset({"type", "condition", "maxIterations", "steps"}),
}


def _require_bounded_json(value: Any, label: str) -> None:
    try:
        encoded = json.dumps(value, separators=(",", ":")).encode()
    except (TypeError, ValueError, RecursionError) as error:
        raise WorkflowError(f"{label} must be an acyclic JSON document") from error
    if len(encoded) > _MAX_DOCUMENT_BYTES:
        raise WorkflowError(f"{label} exceeds the 1048576-byte limit")


def adapt_safe_workflow(
    document: Any, *, adapter: str, context: dict[str, bool | list[bool]] | None = None
) -> dict[str, Any]:
    """Normalize a supported authoring format into the non-executable UEEF IR."""

    _require_bounded_json(document, "workflow")

    if adapter == "ueef-native/v1":
        if not isinstance(document, dict) or document.get("schemaVersion") != 1:
            raise WorkflowError("ueef-native/v1 workflow schemaVersion must be 1")
        normalized = copy.deepcopy(document)
    elif adapter == "spec-kit/v0.16":
        if not isinstance(document, dict) or str(document.get("schema_version")) != "1.0":
            raise WorkflowError("spec-kit/v0.16 workflow schema_version must be 1.0")
        workflow = document.get("workflow")
        if not isinstance(workflow, dict):
            raise WorkflowError("spec-kit workflow metadata must be an object")
        workflow_id = workflow.get("id")
        workflow_name = workflow.get("name")
        workflow_version = workflow.get("version")
        if not isinstance(workflow_id, str) or not _WORKFLOW_ID.fullmatch(workflow_id):
            raise WorkflowError("spec-kit workflow id is invalid")
        if (
            not isinstance(workflow_name, str)
            or not workflow_name.strip()
            or len(workflow_name) > 200
        ):
            raise WorkflowError("spec-kit workflow name is invalid")
        if not isinstance(workflow_version, str) or not _SEMVER.fullmatch(workflow_version):
            raise WorkflowError("spec-kit workflow version is invalid")
        raw_steps = copy.deepcopy(document.get("steps"))
        if not isinstance(raw_steps, list):
            raise WorkflowError("spec-kit workflow steps must be an array")

        def translate(steps: list[Any]) -> list[Any]:
            translated: list[Any] = []
            for raw_step in steps:
                if not isinstance(raw_step, dict):
                    translated.append(raw_step)
                    continue
                step = copy.deepcopy(raw_step)
                if step.get("type") == "gate":
                    raise WorkflowError(
                        "spec-kit human gate requires an approval-bound IR representation"
                    )
                for key in ("then", "else", "steps"):
                    if isinstance(step.get(key), list):
                        step[key] = translate(step[key])
                branches = step.get("branches")
                if isinstance(branches, list):
                    step["branches"] = [
                        translate(branch) if isinstance(branch, list) else branch
                        for branch in branches
                    ]
                translated.append(step)
            return translated

        normalized = {
            "schemaVersion": 1,
            "workflowId": workflow_id,
            "steps": translate(raw_steps),
        }
    else:
        raise WorkflowError(f"unsupported workflow adapter: {adapter}")
    # Expansion is the security validator: normalization cannot bless an executable step.
    expand_safe_workflow(normalized, context=context)
    return normalized


def compose_safe_workflow(
    document: Any,
    overlays: Any,
    *,
    adapter: str = "ueef-native/v1",
    context: dict[str, bool | list[bool]] | None = None,
) -> dict[str, Any]:
    """Apply deterministic, bounded anchor edits and return a digest-bound expanded plan."""

    _require_bounded_json(overlays, "workflow overlays")
    normalized = adapt_safe_workflow(document, adapter=adapter, context=context)
    workflow_id = normalized.get("workflowId")
    raw_overlays = overlays if overlays is not None else []
    if not isinstance(raw_overlays, list) or len(raw_overlays) > _MAX_OVERLAYS:
        raise WorkflowError("workflow overlays must be an array of at most 64 items")
    parsed: list[dict[str, Any]] = []
    conflict_keys: set[tuple[int, int, str]] = set()
    for index, overlay in enumerate(raw_overlays):
        if not isinstance(overlay, dict):
            raise WorkflowError(f"overlays[{index}] must be an object")
        enabled = overlay.get("enabled", True)
        if not isinstance(enabled, bool):
            raise WorkflowError(f"overlays[{index}].enabled must be boolean")
        if not enabled:
            continue
        overlay_id = overlay.get("id")
        source_level = overlay.get("sourceLevel")
        priority = overlay.get("priority", 10)
        edits = overlay.get("edits")
        if not isinstance(overlay_id, str) or not _ID.fullmatch(overlay_id):
            raise WorkflowError(f"overlays[{index}].id is invalid")
        if source_level not in _SOURCE_RANK:
            raise WorkflowError(f"overlays[{index}].sourceLevel is invalid")
        if (
            isinstance(priority, bool)
            or not isinstance(priority, int)
            or not -1000 <= priority <= 1000
        ):
            raise WorkflowError(f"overlays[{index}].priority is invalid")
        if overlay.get("extends") != workflow_id:
            raise WorkflowError(f"overlays[{index}] does not extend the selected workflow")
        if not isinstance(edits, list) or not 1 <= len(edits) <= _MAX_EDITS:
            raise WorkflowError(f"overlays[{index}].edits must contain 1-100 edits")
        for edit_index, edit in enumerate(edits):
            if not isinstance(edit, dict):
                raise WorkflowError(f"overlays[{index}].edits[{edit_index}] must be an object")
            operation = edit.get("operation")
            anchor = edit.get("anchor")
            if operation not in {"insert_before", "insert_after", "replace", "remove"}:
                raise WorkflowError(f"overlays[{index}].edits[{edit_index}] operation is invalid")
            if not isinstance(anchor, str) or not _ID.fullmatch(anchor):
                raise WorkflowError(f"overlays[{index}].edits[{edit_index}] anchor is invalid")
            if operation == "remove":
                if "step" in edit:
                    raise WorkflowError("remove overlay edits cannot include a step")
            elif not isinstance(edit.get("step"), dict):
                raise WorkflowError(f"{operation} overlay edit requires a step object")
            key = (_SOURCE_RANK[source_level], priority, anchor)
            if operation in {"replace", "remove"} and key in conflict_keys:
                raise WorkflowError("ambiguous destructive overlay conflict at equal precedence")
            if operation in {"replace", "remove"}:
                conflict_keys.add(key)
        parsed.append({**copy.deepcopy(overlay), "priority": priority})
    parsed.sort(
        key=lambda value: (_SOURCE_RANK[value["sourceLevel"]], value["priority"], value["id"])
    )
    steps = copy.deepcopy(normalized.get("steps"))
    if not isinstance(steps, list):
        raise WorkflowError("workflow steps must be an array")

    def locate(items: list[dict[str, Any]], anchor: str) -> tuple[list[dict[str, Any]], int] | None:
        for position, step in enumerate(items):
            if not isinstance(step, dict):
                continue
            if step.get("id") == anchor:
                return items, position
            for key in ("then", "else", "steps"):
                nested = step.get(key)
                if isinstance(nested, list) and (found := locate(nested, anchor)):
                    return found
            branches = step.get("branches")
            if isinstance(branches, list):
                for branch in branches:
                    if isinstance(branch, list) and (found := locate(branch, anchor)):
                        return found
        return None

    attribution: list[dict[str, str]] = []
    for overlay in parsed:
        for edit in overlay["edits"]:
            found = locate(steps, edit["anchor"])
            if found is None:
                raise WorkflowError(f"overlay anchor does not exist: {edit['anchor']}")
            owner, position = found
            operation = edit["operation"]
            if operation == "remove":
                owner.pop(position)
            elif operation == "replace":
                owner[position] = copy.deepcopy(edit["step"])
            elif operation == "insert_before":
                owner.insert(position, copy.deepcopy(edit["step"]))
            else:
                owner.insert(position + 1, copy.deepcopy(edit["step"]))
            attribution.append(
                {"overlayId": overlay["id"], "operation": operation, "anchor": edit["anchor"]}
            )
    composed = {**normalized, "steps": steps}
    expanded = expand_safe_workflow(composed, context=context)
    canonical = json.dumps(
        {"workflow": composed, "attribution": attribution}, sort_keys=True, separators=(",", ":")
    )
    return {
        "schemaVersion": 1,
        "format": "ueef-safe-workflow-plan/v1",
        "workflow": composed,
        "expanded": expanded,
        "attribution": attribution,
        "digest": hashlib.sha256(canonical.encode()).hexdigest(),
    }


def expand_safe_workflow(
    document: Any, context: dict[str, bool | list[bool]] | None = None
) -> list[dict[str, Any]]:
    if not isinstance(document, dict) or document.get("schemaVersion") != 1:
        raise WorkflowError("safe workflow schemaVersion must be 1")
    context = context or {}

    def valid_context_value(value: Any) -> bool:
        return isinstance(value, bool) or (
            isinstance(value, list)
            and 1 <= len(value) <= _MAX_LOOP
            and all(isinstance(item, bool) for item in value)
        )

    if len(context) > 100 or any(
        not isinstance(name, str) or not _ID.fullmatch(name) or not valid_context_value(value)
        for name, value in context.items()
    ):
        raise WorkflowError(
            "workflow context must contain at most 100 named booleans or bounded boolean sequences"
        )
    result: list[dict[str, Any]] = []

    def expand(steps: Any, prefix: str = "", incoming: tuple[str, ...] = ()) -> tuple[str, ...]:
        if not isinstance(steps, list):
            raise WorkflowError("workflow steps must be an array")
        frontier = incoming
        for step in steps:
            if len(result) >= _MAX_STEPS:
                raise WorkflowError("expanded workflow exceeds the task limit")
            if not isinstance(step, dict):
                raise WorkflowError("workflow step must be an object")
            kind = step.get("type", "task")
            if kind in {"shell", "command", "prompt"}:
                raise WorkflowError(f"unsafe workflow step is forbidden: {kind}")
            allowed_fields = _STEP_FIELDS.get(kind)
            if allowed_fields is None:
                raise WorkflowError(f"unsupported safe workflow step: {kind}")
            unknown_fields = sorted(set(step) - allowed_fields)
            if unknown_fields:
                raise WorkflowError(
                    f"{kind} step contains unsupported fields: {', '.join(unknown_fields)}"
                )
            if kind == "task":
                task_id = step.get("id")
                if not isinstance(task_id, str) or not _ID.fullmatch(task_id):
                    raise WorkflowError("task step requires a bounded safe id")
                full_id = prefix + task_id
                if len(full_id) > 128:
                    raise WorkflowError("expanded task id exceeds 128 characters")
                title = step.get("title", task_id)
                if not isinstance(title, str) or not title.strip() or len(title) > 200:
                    raise WorkflowError(
                        "task title must be a non-empty string up to 200 characters"
                    )
                result.append(
                    {
                        "id": full_id,
                        "title": title,
                        "dependsOn": list(frontier),
                    }
                )
                frontier = (full_id,)
            elif kind == "if":
                condition = step.get("condition")
                if (
                    not isinstance(condition, str)
                    or condition not in context
                    or not isinstance(context[condition], bool)
                ):
                    raise WorkflowError("if step condition must name a supplied boolean")
                frontier = expand(
                    step.get("then" if context[condition] else "else", []), prefix, frontier
                )
            elif kind == "fan-out":
                branches = step.get("branches")
                if not isinstance(branches, list) or not 1 <= len(branches) <= 16:
                    raise WorkflowError("fan-out requires 1-16 branches")
                tails: list[str] = []
                for branch_index, branch in enumerate(branches, 1):
                    tails.extend(expand(branch, f"{prefix}B{branch_index}-", frontier))
                frontier = tuple(dict.fromkeys(tails))
            elif kind == "fan-in":
                raw_gate_id = step.get("id", "FAN-IN")
                if (
                    not isinstance(raw_gate_id, str)
                    or not raw_gate_id.strip()
                    or len(raw_gate_id) > 128
                ):
                    raise WorkflowError("fan-in id must be a bounded non-empty string")
                gate_id = prefix + raw_gate_id
                result.append({"id": gate_id, "title": "Fan-in gate", "dependsOn": list(frontier)})
                frontier = (gate_id,)
            elif kind in {"while", "do-while"}:
                iterations = step.get("maxIterations")
                if (
                    isinstance(iterations, bool)
                    or not isinstance(iterations, int)
                    or not 1 <= iterations <= _MAX_LOOP
                ):
                    raise WorkflowError("loop maxIterations must be an integer from 1 through 20")
                condition = step.get("condition")
                if condition is not None and (
                    not isinstance(condition, str) or condition not in context
                ):
                    raise WorkflowError("loop condition must name a supplied boolean")
                body = step.get("steps")
                if not isinstance(body, list):
                    raise WorkflowError("loop steps must be an array")
                condition_value = True if condition is None else context[condition]
                if isinstance(condition_value, bool):
                    bounded_iterations = (
                        iterations if condition_value else (1 if kind == "do-while" else 0)
                    )
                    for iteration in range(1, bounded_iterations + 1):
                        frontier = expand(body, f"{prefix}I{iteration}-", frontier)
                else:
                    for iteration in range(1, iterations + 1):
                        condition_index = iteration - 1 if kind == "while" else iteration - 2
                        should_continue = (
                            True
                            if kind == "do-while" and iteration == 1
                            else condition_index < len(condition_value)
                            and condition_value[condition_index]
                        )
                        if not should_continue:
                            break
                        frontier = expand(body, f"{prefix}I{iteration}-", frontier)
        return frontier

    expand(document.get("steps"))
    ids = [item["id"] for item in result]
    if len(ids) != len(set(ids)):
        raise WorkflowError("expanded workflow contains duplicate task IDs")
    return result
