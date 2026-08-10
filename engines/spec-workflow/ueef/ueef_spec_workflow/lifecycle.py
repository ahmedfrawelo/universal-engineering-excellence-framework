"""Mandatory authored lifecycle readiness checks before workflow execution."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from .compiler import compile_plan, parse_tasks
from .errors import WorkflowError

_REQUIRED = ("constitution.md", "spec.md", "clarifications.md", "plan.md", "tasks.md")
_PLACEHOLDER = re.compile(r"\{\{[^}]+\}\}")
_STATUS = re.compile(r"(?m)^Status:\s*(READY|RESOLVED)\s*$")
_REQUIREMENT = re.compile(
    r"(?m)^(?:#{1,6}\s+|[-*]\s+|\|\s*)(REQ-\d{3})(?=\s*(?::|\||$))"
)
_ACCEPTANCE = re.compile(
    r"(?m)^(?:#{1,6}\s+|[-*]\s+|\|\s*)(AC-\d{3})(?=\s*(?::|\||$))"
)


def prepare_workflow(root: Path, workflow_id: str, route: dict[str, Any]) -> dict[str, Any]:
    missing = [name for name in _REQUIRED if not (root / name).is_file()]
    if missing:
        raise WorkflowError(f"workflow lifecycle is missing required artifacts: {missing}")
    documents = {name: (root / name).read_text(encoding="utf-8-sig") for name in _REQUIRED}
    unresolved = [name for name, text in documents.items() if _PLACEHOLDER.search(text)]
    if unresolved:
        raise WorkflowError(f"workflow lifecycle contains unresolved placeholders: {unresolved}")
    for name, text in documents.items():
        expected = "RESOLVED" if name == "clarifications.md" else "READY"
        match = _STATUS.search(text)
        if match is None or match.group(1) != expected:
            raise WorkflowError(f"{name} is not READY")
    requirements = set(_REQUIREMENT.findall(documents["spec.md"]))
    acceptance = set(_ACCEPTANCE.findall(documents["spec.md"]))
    if not requirements or not acceptance:
        raise WorkflowError("spec.md must define structured REQ and AC identifiers")
    plan_requirements = set(_REQUIREMENT.findall(documents["plan.md"]))
    plan_acceptance = set(_ACCEPTANCE.findall(documents["plan.md"]))
    missing_plan_requirements = requirements - plan_requirements
    missing_plan_acceptance = acceptance - plan_acceptance
    if missing_plan_requirements or missing_plan_acceptance:
        raise WorkflowError(
            "plan.md is missing structured traceability: "
            f"requirements={sorted(missing_plan_requirements)}, "
            f"acceptance={sorted(missing_plan_acceptance)}"
        )
    parsed_tasks = parse_tasks(documents["tasks.md"])
    requirement_tasks: dict[str, list[str]] = {item: [] for item in requirements}
    acceptance_tasks: dict[str, list[str]] = {item: [] for item in acceptance}
    for task in parsed_tasks:
        task_id = task["id"]
        task_requirements = set(task["requirements"])
        task_acceptance = set(task["acceptance"])
        unknown_requirements = task_requirements - requirements
        unknown_acceptance = task_acceptance - acceptance
        if unknown_requirements or unknown_acceptance:
            raise WorkflowError(
                f"{task_id} structured task trace references unknown identifiers: "
                f"requirements={sorted(unknown_requirements)}, "
                f"acceptance={sorted(unknown_acceptance)}"
            )
        for requirement in task_requirements:
            requirement_tasks[requirement].append(task_id)
        for criterion in task_acceptance:
            acceptance_tasks[criterion].append(task_id)
    missing_requirements = sorted(
        item for item, task_ids in requirement_tasks.items() if not task_ids
    )
    missing_acceptance = sorted(item for item, task_ids in acceptance_tasks.items() if not task_ids)
    if missing_requirements or missing_acceptance:
        raise WorkflowError(
            "tasks.md structured task trace is incomplete: "
            f"requirements={missing_requirements}, acceptance={missing_acceptance}"
        )
    if re.search(r"(?im)^Status:\s*(PENDING|ASSUMED)\s*$", documents["clarifications.md"]):
        raise WorkflowError("clarifications.md contains unresolved decisions")
    graph = compile_plan(documents["tasks.md"], workflow_id, route)
    return {
        "schemaVersion": 2,
        "status": "READY",
        "workflowId": workflow_id,
        "artifacts": list(_REQUIRED),
        "traceability": {
            "requirements": sorted(requirements),
            "acceptance": sorted(acceptance),
            "requirementTasks": {
                key: sorted(value) for key, value in sorted(requirement_tasks.items())
            },
            "acceptanceTasks": {
                key: sorted(value) for key, value in sorted(acceptance_tasks.items())
            },
        },
        "graph": graph,
    }
