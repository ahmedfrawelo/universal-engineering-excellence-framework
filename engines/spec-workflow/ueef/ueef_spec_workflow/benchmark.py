"""Reproducible comparison of recorded workflow runs."""

from __future__ import annotations

import json
import platform
import tempfile
import time
from pathlib import Path
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
    if not isinstance(document, dict) or document.get("schemaVersion") not in {1, 2}:
        raise WorkflowError("benchmark schemaVersion must be 1 or 2")
    schema_version = document["schemaVersion"]
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
        if schema_version == 2:
            if not isinstance(run.get("evidenceComplete"), bool):
                raise WorkflowError(f"runs[{index}].evidenceComplete must be boolean")
            if (
                isinstance(run.get("recoveryMs"), bool)
                or not isinstance(run.get("recoveryMs"), int)
                or run["recoveryMs"] < 0
            ):
                raise WorkflowError(f"runs[{index}].recoveryMs must be non-negative integer")
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
            **{metric: sum(item[metric] for item in values) / count for metric in _METRICS[1:]},
        }
        if schema_version == 2:
            summary[mode]["evidenceCompleteness"] = (
                sum(1 for item in values if item["evidenceComplete"]) / count
            )
            summary[mode]["recoveryMs"] = sum(item["recoveryMs"] for item in values) / count
    return {
        "schemaVersion": schema_version,
        "scenarioId": scenario_id,
        "workloadDigest": workload_digest,
        "summary": summary,
        "source": "recorded-runs",
        "limitations": document.get("limitations", "No general productivity claim is inferred."),
    }


def record_control_loop_benchmark(samples: int = 5) -> dict[str, Any]:
    """Measure a small local recovery workload; this is not a productivity study."""

    if not 1 <= samples <= 100:
        raise WorkflowError("benchmark samples must be from 1 through 100")
    from .controller import Controller
    from .model import TaskGraph
    from .orchestration import HostResult
    from .scheduler import Scheduler
    from .state import ExecutionState, StateStore

    tasks = [
        {
            "id": f"TASK-{index:03d}",
            "title": f"Benchmark task {index}",
            "requirements": ["REQ-BENCH"],
            "acceptance": ["AC-BENCH"],
            "writeSet": [f"bench/{index}"],
            "parallelSafe": True,
        }
        for index in range(1, 13)
    ]
    graph = TaskGraph.from_dict(
        {
            "schemaVersion": 1,
            "workflowId": "control-loop-benchmark",
            "policy": {
                "tier": "T4",
                "maxWorkers": 4,
                "tokenBudgetMode": "bounded",
                "retryLimit": 1,
                "shellPolicy": "deny",
                "allowedShellCommands": [],
            },
            "tasks": tasks,
        }
    )
    runs: list[dict[str, Any]] = []

    def measured(run_id: str, mode: str, operation) -> None:
        started = time.perf_counter_ns()
        retries, evidence_complete = operation()
        elapsed = max(0, round((time.perf_counter_ns() - started) / 1_000_000))
        runs.append(
            {
                "runId": run_id,
                "mode": mode,
                "success": True,
                "makespanMs": elapsed,
                "tokens": len(tasks) * 500,
                "retries": retries,
                "conflicts": 0,
                "rework": 0,
                "recoveryMs": elapsed,
                "evidenceComplete": evidence_complete,
            }
        )

    for sample in range(1, samples + 1):

        def single():
            state = ExecutionState.new(graph)
            for index, task in enumerate(graph.tasks):
                state.reserve_wave([(task.id, "single")], 1)
                state.transition(graph, task.id, "start", worker="single")
                if index == 0:
                    state.transition(graph, task.id, "fail", error="injected")
                    state.reserve_wave([(task.id, "single")], 1)
                    state.transition(graph, task.id, "start", worker="single")
                state.transition(graph, task.id, "complete", evidence="recorded")
            return 1, all(run.evidence for run in state.tasks.values())

        measured(f"single-{sample}", "single-agent", single)

        def static():
            state = ExecutionState.new(graph)
            injected = False
            while state.overall_status != "DONE":
                decision = Scheduler(graph).decide(state)
                state.reserve_wave(
                    [(item.task_id, item.worker) for item in decision.tasks],
                    decision.desired_workers,
                )
                for item in decision.tasks:
                    state.transition(graph, item.task_id, "start", worker=item.worker)
                    if not injected:
                        state.transition(graph, item.task_id, "fail", error="injected")
                        injected = True
                    else:
                        state.transition(graph, item.task_id, "complete", evidence="recorded")
            return 1, all(run.evidence for run in state.tasks.values())

        measured(f"static-{sample}", "ueef-static", static)

        def dynamic():
            class Runtime:
                capabilities = frozenset({"dispatch", "poll", "close"})

                def __init__(self):
                    self.contracts = {}
                    self.injected = False

                def dispatch(self, contract):
                    self.contracts[contract.attempt_id] = contract
                    return contract.attempt_id

                def poll(self, handle):
                    contract = self.contracts[handle]
                    if not self.injected:
                        self.injected = True
                        return HostResult.for_contract(contract, "fail", error="injected")
                    evidence = json.dumps(
                        {criterion: "recorded" for criterion in contract.acceptance},
                        separators=(",", ":"),
                    )
                    return HostResult.for_contract(contract, "complete", evidence=evidence)

                def close(self, handle):
                    pass

                def heartbeat(self, handle):
                    pass

                def cancel(self, handle):
                    pass

            with tempfile.TemporaryDirectory() as directory:
                store = StateStore(Path(directory) / "state.json")
                store.save(ExecutionState.new(graph))
                report = Controller(graph, Runtime()).run(store)
                state = store.load(graph)
                return 1, report.status == "DONE" and all(
                    run.evidence for run in state.tasks.values()
                )

        measured(f"dynamic-{sample}", "dynamic-team", dynamic)

    return {
        "schemaVersion": 2,
        "scenarioId": "local-control-loop-recovery-v1",
        "workloadDigest": graph.digest,
        "environment": {"python": platform.python_version(), "platform": platform.platform()},
        "limitations": (
            "Local microbenchmark with one deterministic injected retry; it measures "
            "control-loop overhead and evidence capture, not human or general engineering "
            "productivity."
        ),
        "runs": runs,
    }
