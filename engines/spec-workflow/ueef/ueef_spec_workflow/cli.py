"""Command-line interface for validation, scheduling, transitions, and resume."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from .adapters import get_adapter
from .benchmark import compare_runs
from .convergence import converge
from .errors import WorkflowError
from .model import TaskGraph
from .orchestration import Orchestrator, RecordedHostRuntime
from .scheduler import Scheduler
from .state import ExecutionState, StateStore
from .team_manager import TeamManager
from .upstream import validate_workflow, verify_snapshot


def _print(value: Any) -> None:
    print(json.dumps(value, ensure_ascii=False, indent=2))


def _graph(path: str) -> TaskGraph:
    return TaskGraph.from_json_file(path)


def _validate(args: argparse.Namespace) -> dict[str, Any]:
    graph = _graph(args.graph)
    return {
        "schemaVersion": 1,
        "valid": True,
        "workflowId": graph.workflow_id,
        "graphDigest": graph.digest,
        "taskCount": len(graph.tasks),
        "criticalPathWeights": graph.downstream_weights(),
        "policy": graph.policy.to_dict(),
    }


def _init(args: argparse.Namespace) -> dict[str, Any]:
    graph = _graph(args.graph)
    store = StateStore(args.state)
    if store.path.exists() and not args.force:
        raise WorkflowError(f"execution state already exists: {store.path}; use --force to replace")
    state = ExecutionState.new(graph)
    store.save(state)
    return state.to_dict()


def _status(args: argparse.Namespace) -> dict[str, Any]:
    graph = _graph(args.graph)
    state = StateStore(args.state).load(graph)
    return state.to_dict()


def _schedule(args: argparse.Namespace) -> dict[str, Any]:
    graph = _graph(args.graph)
    store = StateStore(args.state)
    state = store.load(graph)
    previous_revision = state.revision
    decision = Scheduler(graph).decide(state)
    contracts = get_adapter(args.adapter).build(graph, decision)
    state.reserve_wave(
        [(item.task_id, item.worker) for item in decision.tasks],
        decision.desired_workers,
    )
    store.save(state, expected_revision=previous_revision)
    result = decision.to_dict()
    result["dispatchContracts"] = [contract.to_dict() for contract in contracts]
    result["persistedRevision"] = state.revision
    return result


def _transition(args: argparse.Namespace) -> dict[str, Any]:
    graph = _graph(args.graph)
    store = StateStore(args.state)
    state = store.load(graph)
    previous_revision = state.revision
    if args.expected_revision is not None and args.expected_revision != previous_revision:
        raise WorkflowError(
            f"state revision conflict: expected {args.expected_revision}, found {previous_revision}"
        )
    state.transition(
        graph,
        args.task,
        args.action,
        worker=args.worker,
        evidence=args.evidence,
        error=args.error,
        tokens=args.tokens,
    )
    store.save(state, expected_revision=previous_revision)
    return state.to_dict()


def _write_new_json(path: str, value: dict[str, Any]) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def _converge(args: argparse.Namespace) -> dict[str, Any]:
    graph = _graph(args.graph)
    state = StateStore(args.state).load(graph)
    with open(args.findings, encoding="utf-8-sig") as handle:
        findings = json.load(handle)
    if Path(args.output_graph).exists() or Path(args.output_state).exists():
        raise WorkflowError("convergence outputs must not already exist")
    amended, migrated = converge(graph, state, findings)
    _write_new_json(args.output_graph, amended.to_dict())
    _write_new_json(args.output_state, migrated.to_dict())
    return {
        "schemaVersion": 1,
        "workflowId": amended.workflow_id,
        "previousGraphDigest": graph.digest,
        "graphDigest": amended.digest,
        "addedTaskCount": len(amended.tasks) - len(graph.tasks),
        "outputGraph": str(Path(args.output_graph).resolve()),
        "outputState": str(Path(args.output_state).resolve()),
    }


def _benchmark(args: argparse.Namespace) -> dict[str, Any]:
    with open(args.input, encoding="utf-8-sig") as handle:
        return compare_runs(json.load(handle))


def _run(args: argparse.Namespace) -> dict[str, Any]:
    with open(args.results, encoding="utf-8-sig") as handle:
        runtime = RecordedHostRuntime(json.load(handle))
    graph = _graph(args.graph)
    report = Orchestrator(graph, args.adapter).run_persisted_wave(
        StateStore(args.state), runtime
    )
    return {
        "schemaVersion": 1,
        "desiredWorkers": report.desired_workers,
        "scaleAction": report.scale_action,
        "contracts": [contract.to_dict() for contract in report.contracts],
        "results": [
            {
                "taskId": result.task_id,
                "worker": result.worker,
                "outcome": result.outcome,
                "tokens": result.tokens,
            }
            for result in report.results
        ],
    }


def _apply_results(args: argparse.Namespace) -> dict[str, Any]:
    with open(args.results, encoding="utf-8-sig") as handle:
        runtime = RecordedHostRuntime(json.load(handle))
    results = Orchestrator(_graph(args.graph), args.adapter).apply_persisted_results(
        StateStore(args.state), runtime
    )
    return {
        "schemaVersion": 1,
        "appliedResultCount": len(results),
        "results": [
            {"taskId": result.task_id, "worker": result.worker, "outcome": result.outcome}
            for result in results
        ],
    }


def _manage(args: argparse.Namespace) -> dict[str, Any]:
    with open(args.workers, encoding="utf-8-sig") as handle:
        workers = TeamManager.parse_workers(json.load(handle))
    manager = TeamManager(_graph(args.graph), args.adapter)
    return manager.manage_persisted(StateStore(args.state), workers, commit=args.commit).to_dict()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="ueef-spec-workflow",
        description="Validate task graphs and coordinate persistent execution waves.",
    )
    commands = parser.add_subparsers(dest="command", required=True)

    validate = commands.add_parser("validate", help="validate task-graph JSON")
    validate.add_argument("--graph", required=True)
    validate.set_defaults(handler=_validate)

    initialize = commands.add_parser("init", help="initialize execution state")
    initialize.add_argument("--graph", required=True)
    initialize.add_argument("--state", required=True)
    initialize.add_argument("--force", action="store_true")
    initialize.set_defaults(handler=_init)

    status = commands.add_parser("status", help="read and validate resumable state")
    status.add_argument("--graph", required=True)
    status.add_argument("--state", required=True)
    status.set_defaults(handler=_status)

    schedule = commands.add_parser("schedule", help="recommend and persist the next wave")
    schedule.add_argument("--graph", required=True)
    schedule.add_argument("--state", required=True)
    schedule.add_argument("--adapter", default="generic", choices=("generic", "codex", "claude"))
    schedule.set_defaults(handler=_schedule)

    transition = commands.add_parser("transition", help="record a guarded task transition")
    transition.add_argument("--graph", required=True)
    transition.add_argument("--state", required=True)
    transition.add_argument("--task", required=True)
    transition.add_argument(
        "--action",
        required=True,
        choices=("start", "complete", "fail", "block", "unblock", "release"),
    )
    transition.add_argument("--worker")
    transition.add_argument("--evidence")
    transition.add_argument("--error")
    transition.add_argument("--tokens", type=int, default=0)
    transition.add_argument("--expected-revision", type=int)
    transition.set_defaults(handler=_transition)

    convergence = commands.add_parser(
        "converge", help="append verifier-backed gap tasks and migrate state"
    )
    convergence.add_argument("--graph", required=True)
    convergence.add_argument("--state", required=True)
    convergence.add_argument("--findings", required=True)
    convergence.add_argument("--output-graph", required=True)
    convergence.add_argument("--output-state", required=True)
    convergence.set_defaults(handler=_converge)

    benchmark = commands.add_parser(
        "benchmark", help="compare recorded single, static, and dynamic runs"
    )
    benchmark.add_argument("--input", required=True)
    benchmark.set_defaults(handler=_benchmark)

    run = commands.add_parser(
        "run", help="persist a host-returned execution wave and append audit events"
    )
    run.add_argument("--graph", required=True)
    run.add_argument("--state", required=True)
    run.add_argument("--results", required=True)
    run.add_argument("--adapter", default="generic", choices=("generic", "codex", "claude"))
    run.set_defaults(handler=_run)

    apply_results = commands.add_parser(
        "apply-results", help="apply host receipts to an already reserved wave"
    )
    apply_results.add_argument("--graph", required=True)
    apply_results.add_argument("--state", required=True)
    apply_results.add_argument("--results", required=True)
    apply_results.add_argument(
        "--adapter", default="generic", choices=("generic", "codex", "claude")
    )
    apply_results.set_defaults(handler=_apply_results)

    manage = commands.add_parser(
        "manage", help="plan or reserve a capability-matched host management cycle"
    )
    manage.add_argument("--graph", required=True)
    manage.add_argument("--state", required=True)
    manage.add_argument("--workers", required=True)
    manage.add_argument("--adapter", default="generic", choices=("generic", "codex", "claude"))
    manage.add_argument(
        "--commit", action="store_true", help="reserve emitted contracts atomically"
    )
    manage.set_defaults(handler=_manage)

    upstream_status = commands.add_parser(
        "upstream-status", help="verify the vendored Spec Kit snapshot digest"
    )
    upstream_status.set_defaults(handler=lambda _args: verify_snapshot())

    upstream_validate = commands.add_parser(
        "upstream-validate", help="validate YAML using vendored upstream code without execution"
    )
    upstream_validate.add_argument("--workflow", required=True)
    upstream_validate.add_argument(
        "--allow-shell-definition",
        action="store_true",
        help="accept shell definitions for analysis only; this CLI still cannot execute them",
    )
    upstream_validate.set_defaults(
        handler=lambda args: validate_workflow(
            args.workflow, allow_shell=args.allow_shell_definition
        )
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        result = args.handler(args)
        _print(result)
        return 0 if result.get("valid", True) else 1
    except (WorkflowError, OSError) as exc:
        _print({"schemaVersion": 1, "valid": False, "error": str(exc)})
        return 1


if __name__ == "__main__":
    sys.exit(main())
