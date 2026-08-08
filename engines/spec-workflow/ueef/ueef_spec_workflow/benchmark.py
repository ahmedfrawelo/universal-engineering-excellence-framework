"""Reproducible comparison of recorded workflow runs."""

from __future__ import annotations

from typing import Any

from .errors import WorkflowError

_MODES = ("single-agent", "ueef-static", "dynamic-team")
_METRICS = ("success", "makespanMs", "tokens", "retries", "conflicts", "rework")
_MAX_IDENTIFIER_LENGTH = 256


def _identifier(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip() or len(value) > _MAX_IDENTIFIER_LENGTH:
        raise WorkflowError(f"benchmark {field} must be a non-empty string up to 256 characters")
    return value.strip()


def compare_runs(document: Any) -> dict[str, Any]:
    if not isinstance(document, dict) or document.get("schemaVersion") != 1:
        raise WorkflowError("benchmark schemaVersion must be 1")
    scenario_id = _identifier(document.get("scenarioId"), "scenarioId")
    workload_digest = _identifier(document.get("workloadDigest"), "workloadDigest")
    runs = document.get("runs")
    if not isinstance(runs, list) or not runs:
        raise WorkflowError("benchmark requires recorded runs")
    grouped: dict[str, list[dict[str, Any]]] = {mode: [] for mode in _MODES}
    run_ids: set[str] = set()
    for index, run in enumerate(runs):
        if not isinstance(run, dict) or run.get("mode") not in grouped:
            raise WorkflowError(f"runs[{index}] has an unsupported mode")
        run_id = _identifier(run.get("runId"), f"runs[{index}].runId")
        if run_id in run_ids:
            raise WorkflowError(f"duplicate benchmark runId: {run_id}")
        run_ids.add(run_id)
        for metric in _METRICS:
            if metric not in run:
                raise WorkflowError(f"runs[{index}] is missing {metric}")
        if not isinstance(run["success"], bool):
            raise WorkflowError(f"runs[{index}].success must be boolean")
        for metric in _METRICS[1:]:
            if isinstance(run[metric], bool) or not isinstance(run[metric], int) or run[metric] < 0:
                raise WorkflowError(f"runs[{index}].{metric} must be non-negative integer")
        grouped[run["mode"]].append(run)
    missing = [mode for mode, values in grouped.items() if not values]
    if missing:
        raise WorkflowError(f"benchmark is missing modes: {', '.join(missing)}")
    summary: dict[str, Any] = {}
    for mode, values in grouped.items():
        count = len(values)
        summary[mode] = {
            "samples": count,
            "successRate": sum(1 for item in values if item["success"]) / count,
            **{
                metric: sum(item[metric] for item in values) / count
                for metric in _METRICS[1:]
            },
        }
    return {
        "schemaVersion": 1,
        "scenarioId": scenario_id,
        "workloadDigest": workload_digest,
        "summary": summary,
        "source": "recorded-runs",
    }
