"""Command-line interface for validation, scheduling, transitions, and resume."""

from __future__ import annotations

import argparse
import base64
import binascii
import json
import sys
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from .adapters import get_adapter, host_status
from .approvals import ApprovalStore, approval_status_for_task, task_approval_binding
from .benchmark import compare_runs, record_control_loop_benchmark
from .catalog_management import (
    CatalogDocumentStore,
    CatalogRegistryStore,
    build_catalog_plan,
    query_catalog,
)
from .compiler import compile_plan, write_compiled_graph
from .control_plane import aggregate_control_status
from .convergence import converge, replan_canonical
from .customization import resolve_customizations
from .errors import WorkflowError
from .hierarchy import evaluate_hierarchy
from .lifecycle import prepare_workflow
from .migration import migrate_v1, write_migration_bundle
from .model import TaskGraph
from .orchestration import Orchestrator, RecordedHostRuntime
from .package_store import PackageStore
from .portfolio import orchestrate_portfolio
from .safe_workflow import expand_safe_workflow
from .scheduler import Scheduler
from .state import ExecutionState, StateStore
from .team_manager import TeamManager
from .template_composition import compose_templates, materialize_composition


def _print(value: Any) -> None:
    print(json.dumps(value, ensure_ascii=False, indent=2))


def _graph(path: str) -> TaskGraph:
    return TaskGraph.from_json_file(path)


def _decode_trust_keys(entries: object, identity_field: str) -> dict[str, dict[str, bytes]]:
    if not isinstance(entries, list):
        raise WorkflowError("trust policy key collection must be an array")
    result: dict[str, dict[str, bytes]] = {}
    for entry in entries:
        if not isinstance(entry, dict):
            raise WorkflowError("trust policy key entries must be objects")
        identity, key_id, encoded = (
            entry.get(identity_field), entry.get("keyId"), entry.get("secretBase64")
        )
        if (
            not isinstance(identity, str) or not identity
            or not isinstance(key_id, str) or not key_id
            or not isinstance(encoded, str) or not encoded
        ):
            raise WorkflowError("trust policy key identity, keyId, and secretBase64 are required")
        try:
            key = base64.b64decode(encoded, validate=True)
        except (ValueError, binascii.Error) as exc:
            raise WorkflowError("trust policy secretBase64 is invalid") from exc
        if len(key) < 32:
            raise WorkflowError("trust policy keys must contain at least 256 bits")
        owner = result.setdefault(identity, {})
        if key_id in owner:
            raise WorkflowError("trust policy key IDs must be unique per identity")
        owner[key_id] = key
    return result


def _load_trust_policy(
    args: argparse.Namespace, default_root: Path
) -> tuple[dict[str, dict[str, bytes]], dict[str, dict[str, bytes]]]:
    if getattr(args, "legacy_unsigned", False):
        if getattr(args, "trust_policy", None):
            raise WorkflowError("--legacy-unsigned cannot be combined with --trust-policy")
        return {}, {}
    path = Path(getattr(args, "trust_policy", None) or default_root / "trust-policy.json")
    try:
        document = json.loads(path.read_text(encoding="utf-8-sig"))
    except FileNotFoundError as exc:
        raise WorkflowError(
            f"trusted production mode requires a trust policy: {path}; "
            "use --legacy-unsigned only for explicit compatibility"
        ) from exc
    except json.JSONDecodeError as exc:
        raise WorkflowError(f"invalid trust policy JSON: {exc}") from exc
    if not isinstance(document, dict) or document.get("schemaVersion") != 1:
        raise WorkflowError("trust policy schemaVersion must be 1")
    approvals = _decode_trust_keys(document.get("approvalKeys", []), "identity")
    packages = _decode_trust_keys(document.get("packageSignerKeys", []), "signerId")
    return approvals, packages


def _load_verifier_keys(
    args: argparse.Namespace, default_root: Path
) -> dict[str, dict[str, bytes]]:
    if getattr(args, "legacy_unsigned", False):
        if getattr(args, "trust_policy", None):
            raise WorkflowError("--legacy-unsigned cannot be combined with --trust-policy")
        return {}
    path = Path(getattr(args, "trust_policy", None) or default_root / "trust-policy.json")
    try:
        document = json.loads(path.read_text(encoding="utf-8-sig"))
    except FileNotFoundError as exc:
        raise WorkflowError(
            f"trusted hierarchy verification requires a trust policy: {path}"
        ) from exc
    except json.JSONDecodeError as exc:
        raise WorkflowError(f"invalid trust policy JSON: {exc}") from exc
    if not isinstance(document, dict) or document.get("schemaVersion") != 1:
        raise WorkflowError("trust policy schemaVersion must be 1")
    return _decode_trust_keys(document.get("verifierKeys", []), "verifierId")


def _approval_store(args: argparse.Namespace) -> ApprovalStore:
    approval_keys, _ = _load_trust_policy(args, Path(args.approvals).parent)
    return ApprovalStore(
        args.approvals,
        trusted_keys=approval_keys,
        require_signatures=not getattr(args, "legacy_unsigned", False),
    )


def _package_store(args: argparse.Namespace) -> PackageStore:
    _, package_keys = _load_trust_policy(args, Path(args.store))
    return PackageStore(
        Path(args.store),
        trusted_signers=package_keys,
        require_attestation=not getattr(args, "legacy_unsigned", False),
    )


def _add_trust_options(command: argparse.ArgumentParser) -> None:
    command.add_argument("--trust-policy", help="schema-v1 local trusted-key policy")
    command.add_argument(
        "--legacy-unsigned",
        action="store_true",
        help="explicit compatibility mode; never treated as trusted production",
    )


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


def _compile(args: argparse.Namespace) -> dict[str, Any]:
    tasks_path = Path(args.tasks)
    route_path = Path(args.route)
    try:
        route = json.loads(route_path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError as exc:
        raise WorkflowError(f"invalid route JSON: {exc}") from exc
    graph = compile_plan(
        tasks_path.read_text(encoding="utf-8-sig"),
        args.workflow_id,
        route,
        requested_max_workers=args.max_workers,
    )
    changed = write_compiled_graph(Path(args.output), graph, check=args.check)
    compiled = TaskGraph.from_dict(graph)
    return {
        "schemaVersion": 2,
        "valid": True,
        "workflowId": compiled.workflow_id,
        "graphDigest": compiled.digest,
        "sourceDigest": compiled.source_digest,
        "routeDigest": compiled.route_digest,
        "executionSpecDigest": compiled.execution_spec_digest,
        "changed": changed,
        "checked": bool(args.check),
        "output": str(Path(args.output)),
    }


def _init(args: argparse.Namespace) -> dict[str, Any]:
    graph = _graph(args.graph)
    store = StateStore(args.state)
    expected_revision: int | None = None
    if store.path.exists():
        if not args.force:
            raise WorkflowError(
                f"execution state already exists: {store.path}; use --force to replace"
            )
        if args.current_execution_id is None or args.current_revision is None:
            raise WorkflowError(
                "force init requires --current-execution-id and --current-revision"
            )
        current = store.load(graph)
        if current.execution_id != args.current_execution_id:
            raise WorkflowError("force init current executionId does not match persisted state")
        if current.revision != args.current_revision:
            raise WorkflowError("force init current revision does not match persisted state")
        expected_revision = current.revision
    elif args.force:
        raise WorkflowError("force init cannot replace missing execution state")
    state = ExecutionState.new(graph)
    store.save(state, expected_revision=expected_revision)
    return state.to_dict()


def _status(args: argparse.Namespace) -> dict[str, Any]:
    graph = _graph(args.graph)
    state = StateStore(args.state).load(graph)
    return state.to_dict()


def _pause(args: argparse.Namespace) -> dict[str, Any]:
    graph = _graph(args.graph)
    store = StateStore(args.state)
    state = store.load(graph)
    previous = state.revision
    state.pause(args.reason)
    store.save(state, expected_revision=previous)
    return state.to_dict()


def _resume(args: argparse.Namespace) -> dict[str, Any]:
    graph = _graph(args.graph)
    store = StateStore(args.state)
    state = store.load(graph)
    previous = state.revision
    state.resume()
    store.save(state, expected_revision=previous)
    return state.to_dict()


def _prepare(args: argparse.Namespace) -> dict[str, Any]:
    route = json.loads(Path(args.route).read_text(encoding="utf-8-sig"))
    report = prepare_workflow(Path(args.root), args.workflow_id, route)
    if args.output:
        write_compiled_graph(Path(args.output), report["graph"])
    return {key: value for key, value in report.items() if key != "graph"} | {
        "graphDigest": TaskGraph.from_dict(report["graph"]).digest,
        "output": args.output,
    }


def _hierarchy(args: argparse.Namespace) -> dict[str, Any]:
    path = Path(args.input)
    return evaluate_hierarchy(
        json.loads(path.read_text(encoding="utf-8-sig")),
        trusted_verifiers=_load_verifier_keys(args, path.parent),
        require_signatures=not args.legacy_unsigned,
    )


def _customizations(args: argparse.Namespace) -> dict[str, Any]:
    document = json.loads(Path(args.input).read_text(encoding="utf-8-sig"))
    route = json.loads(Path(args.route).read_text(encoding="utf-8-sig"))
    if not isinstance(route, dict) or route.get("schemaVersion") != 3:
        raise WorkflowError("route must be a schema-version-3 object")
    economy = route.get("tokenEconomy")
    if not isinstance(economy, dict):
        raise WorkflowError("route.tokenEconomy must be an object")
    worker_cap = economy.get("maxWorkerCount")
    if isinstance(worker_cap, bool) or not isinstance(worker_cap, int) or worker_cap < 1:
        raise WorkflowError("route maxWorkerCount must be a positive integer")
    return resolve_customizations(
        document,
        route_worker_cap=worker_cap,
        route_token_budget=economy.get("tokenBudget"),
        route_retry_limit=1,
    )


def _route_limits(path: str) -> tuple[int, int | None, int]:
    route = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    if not isinstance(route, dict) or route.get("schemaVersion") != 3:
        raise WorkflowError("route must be a schema-version-3 object")
    economy = route.get("tokenEconomy")
    if not isinstance(economy, dict):
        raise WorkflowError("route.tokenEconomy must be an object")
    worker_cap = economy.get("maxWorkerCount")
    token_budget = economy.get("tokenBudget")
    if isinstance(worker_cap, bool) or not isinstance(worker_cap, int) or worker_cap < 1:
        raise WorkflowError("route maxWorkerCount must be a positive integer")
    if token_budget is not None and (
        isinstance(token_budget, bool) or not isinstance(token_budget, int) or token_budget < 0
    ):
        raise WorkflowError("route tokenBudget must be a non-negative integer")
    return worker_cap, token_budget, 1


def _catalog_query(args: argparse.Namespace) -> dict[str, Any]:
    document = json.loads(Path(args.catalog).read_text(encoding="utf-8-sig"))
    return query_catalog(document, action=args.action, term=args.term, target=args.target)


def _catalog_registry(args: argparse.Namespace) -> dict[str, Any]:
    document = json.loads(Path(args.catalog).read_text(encoding="utf-8-sig"))
    registry_path = Path(args.registry)
    state = CatalogRegistryStore(registry_path).transact(
        document,
        action=args.action,
        target=args.target,
        priority=args.priority,
    )
    return {"valid": True, "registry": state, "path": str(registry_path.resolve())}


def _catalog_build(args: argparse.Namespace) -> dict[str, Any]:
    document = json.loads(Path(args.catalog).read_text(encoding="utf-8-sig"))
    registry = CatalogRegistryStore(Path(args.registry)).load(document)
    worker_cap, token_budget, retry_limit = _route_limits(args.route)
    return build_catalog_plan(
        document,
        registry,
        route_worker_cap=worker_cap,
        route_token_budget=token_budget,
        route_retry_limit=retry_limit,
    )


def _catalog_maintain(args: argparse.Namespace) -> dict[str, Any]:
    record = (
        json.loads(Path(args.record).read_text(encoding="utf-8-sig"))
        if args.record
        else None
    )
    return CatalogDocumentStore(Path(args.catalog)).mutate(
        action=args.action,
        expected_digest=args.expected_digest,
        target=args.target,
        source_id=args.source_id,
        record=record,
    )


def _expand_workflow(args: argparse.Namespace) -> dict[str, Any]:
    document = json.loads(Path(args.input).read_text(encoding="utf-8-sig"))
    context = json.loads(Path(args.context).read_text(encoding="utf-8-sig")) if args.context else {}
    steps = expand_safe_workflow(document, context)
    return {"schemaVersion": 1, "taskCount": len(steps), "tasks": steps}


def _host_status(args: argparse.Namespace) -> dict[str, Any]:
    evidence = (
        json.loads(Path(args.evidence).read_text(encoding="utf-8-sig")) if args.evidence else None
    )
    return {"schemaVersion": 1, "hosts": host_status(evidence)}


def _approval_guard(
    args: argparse.Namespace,
    graph: TaskGraph,
    state: ExecutionState,
    task_ids: list[str],
) -> list[dict[str, Any]]:
    threshold = args.require_approval_risk
    required = [task_id for task_id in task_ids if graph.task_map[task_id].risk >= threshold]
    if not required:
        return []
    if not args.approvals:
        raise WorkflowError("high-risk scheduling requires an identity-bound approval ledger")
    ledger = _approval_store(args).load()
    statuses = [
        approval_status_for_task(ledger, graph, state, task_id, now=datetime.now(UTC))
        for task_id in required
    ]
    denied = [item for item in statuses if item["status"] != "APPROVED"]
    if denied:
        summary = ", ".join(f"{item['taskId']}={item['status']}" for item in denied)
        raise WorkflowError(f"approval gate denied scheduling before reservation: {summary}")
    return statuses


def _schedule(args: argparse.Namespace) -> dict[str, Any]:
    graph = _graph(args.graph)
    store = StateStore(args.state)
    state = store.load(graph)
    previous_revision = state.revision
    decision = Scheduler(graph).decide(state)
    approvals = _approval_guard(args, graph, state, [item.task_id for item in decision.tasks])
    state.reserve_wave(
        [(item.task_id, item.worker) for item in decision.tasks],
        decision.desired_workers,
    )
    contracts = get_adapter(args.adapter).build(graph, decision, state)
    store.save(state, expected_revision=previous_revision)
    result = decision.to_dict()
    result["dispatchContracts"] = [contract.to_dict() for contract in contracts]
    result["persistedRevision"] = state.revision
    result["approvalGates"] = approvals
    return result


def _pending_contracts(args: argparse.Namespace) -> dict[str, Any]:
    graph = _graph(args.graph)
    state = StateStore(args.state).load(graph)
    reserved = [
        task_id
        for task_id, task_state in state.tasks.items()
        if task_state.status == "RESERVED"
    ]
    approvals = _approval_guard(args, graph, state, reserved)
    contracts = get_adapter(args.adapter).build_reserved(graph, state)
    return {
        "schemaVersion": 2,
        "workflowId": graph.workflow_id,
        "stateRevision": state.revision,
        "dispatchContracts": [contract.to_dict() for contract in contracts],
        "approvalGates": approvals,
    }


def _commit_staged_reservation(args: argparse.Namespace) -> dict[str, Any]:
    """Promote a validated reservation only after its host receipt was verified."""

    graph = _graph(args.graph)
    target = StateStore(args.state)
    staged = StateStore(args.staged).load(graph)
    if staged.overall_status != "RESERVED":
        raise WorkflowError("staged state must contain a RESERVED wave")
    reserved = [task_id for task_id, item in staged.tasks.items() if item.status == "RESERVED"]
    if not reserved or len(reserved) > graph.policy.max_workers:
        raise WorkflowError("staged reservation has an invalid wave size")
    if target.path.exists():
        current = target.load(graph)
        if staged.execution_id != current.execution_id or staged.revision != current.revision + 1:
            raise WorkflowError(
                "staged reservation identity or revision does not follow current state"
            )
        for task_id, current_task in current.tasks.items():
            staged_task = staged.tasks[task_id]
            if task_id not in reserved and staged_task.to_dict() != current_task.to_dict():
                raise WorkflowError("staged reservation changes a task outside the reserved wave")
            if task_id in reserved and current_task.status != "READY":
                raise WorkflowError("staged reservation can promote only READY tasks")
        target.save(staged, expected_revision=current.revision)
    else:
        if not args.allow_create or staged.revision != 1:
            raise WorkflowError("initial staged reservation requires --allow-create and revision 1")
        target.save(staged)
    return {
        "schemaVersion": 2,
        "status": "RESERVED",
        "persistedRevision": staged.revision,
        "reservedTasks": reserved,
    }


def _approval_status(args: argparse.Namespace) -> dict[str, Any]:
    graph = _graph(args.graph)
    state = StateStore(args.state).load(graph)
    ledger = _approval_store(args).load()
    return {
        "schemaVersion": 2,
        **approval_status_for_task(ledger, graph, state, args.task, now=datetime.now(UTC)),
    }


def _approval_record(args: argparse.Namespace) -> dict[str, Any]:
    graph = _graph(args.graph)
    state = StateStore(args.state).load(graph)
    binding = task_approval_binding(graph, state, args.task)
    store = _approval_store(args)
    keys = store.trusted_keys.get(args.identity, {})
    key_id = args.key_id
    if not args.legacy_unsigned:
        if key_id is None and len(keys) == 1:
            key_id = next(iter(keys))
        if key_id not in keys:
            raise WorkflowError("approval-record requires a trusted --key-id for this identity")
    event = store.record(
        args.gate, args.identity, args.role, args.action, args.evidence_digest, binding,
        now=datetime.now(UTC),
        signing_key=keys.get(key_id) if key_id else None,
        key_id=key_id,
    )
    return {"schemaVersion": 2, "recorded": True, "event": event}


def _compose_templates(args: argparse.Namespace) -> dict[str, Any]:
    sources = {
        name: Path(value)
        for name in ("core", "extension", "preset", "project")
        if (value := getattr(args, name))
    }
    result = compose_templates(sources)
    output = materialize_composition(result, Path(args.output)) if args.output else None
    return {
        "schemaVersion": 1,
        "digest": result.digest,
        "manifest": dict(result.manifest),
        "output": str(output) if output else None,
    }


def _package_install(args: argparse.Namespace) -> dict[str, Any]:
    metadata = (
        json.loads(Path(args.metadata).read_text(encoding="utf-8-sig"))
        if args.metadata
        else None
    )
    return _package_store(args).install(
        args.name,
        args.version,
        Path(args.source),
        metadata=metadata,
        expected_digest=args.expected_digest,
    )


def _package_activate(args: argparse.Namespace) -> dict[str, Any]:
    return _package_store(args).activate(args.name, args.version, args.digest)


def _package_rollback(args: argparse.Namespace) -> dict[str, Any]:
    return _package_store(args).rollback(args.name)


def _package_install_composition(args: argparse.Namespace) -> dict[str, Any]:
    sources = {
        name: Path(value)
        for name in ("core", "extension", "preset", "project")
        if (value := getattr(args, name))
    }
    if not sources:
        raise WorkflowError("package-install-composition requires at least one template layer")
    metadata = (
        json.loads(Path(args.metadata).read_text(encoding="utf-8-sig"))
        if args.metadata
        else None
    )
    composition = compose_templates(sources)
    return _package_store(args).install_composition(
        args.name,
        args.version,
        composition,
        metadata=metadata,
        expected_digest=args.expected_digest,
    )


def _portfolio_status(args: argparse.Namespace) -> dict[str, Any]:
    portfolio = json.loads(Path(args.portfolio).read_text(encoding="utf-8-sig"))
    observed = json.loads(Path(args.observed).read_text(encoding="utf-8-sig"))
    return orchestrate_portfolio(portfolio, observed)


def _control_status(args: argparse.Namespace) -> dict[str, Any]:
    graph = _graph(args.graph)
    state = StateStore(args.state).load(graph)
    evidence = (
        json.loads(Path(args.host_evidence).read_text(encoding="utf-8-sig"))
        if args.host_evidence
        else None
    )
    hosts = host_status(evidence)
    approvals: list[dict[str, Any]] = []
    candidates = [
        task_id
        for task_id, task_state in state.tasks.items()
        if graph.task_map[task_id].risk >= 3 and task_state.status in {"READY", "RESERVED"}
    ]
    if candidates and args.approvals:
        ledger = _approval_store(args).load()
        approvals = [
            approval_status_for_task(ledger, graph, state, task_id, now=datetime.now(UTC))
            for task_id in candidates
        ]
    elif candidates:
        approvals = [{"taskId": task_id, "status": "NOT_CONFIGURED"} for task_id in candidates]

    portfolio_result = None
    if args.portfolio or args.observed:
        if not args.portfolio or not args.observed:
            raise WorkflowError("control-status requires both --portfolio and --observed")
        portfolio_result = orchestrate_portfolio(
            json.loads(Path(args.portfolio).read_text(encoding="utf-8-sig")),
            json.loads(Path(args.observed).read_text(encoding="utf-8-sig")),
        )
    supply_chain_result = (
        json.loads(Path(args.supply_chain).read_text(encoding="utf-8-sig"))
        if args.supply_chain
        else None
    )
    result = aggregate_control_status(
        graph,
        state,
        hosts,
        approvals,
        portfolio_result=portfolio_result,
        supply_chain_result=supply_chain_result,
    )
    result["verificationStatus"] = state.verification_status
    result["approvals"] = approvals
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


def _publish_new_json_pair(
    graph_path: Path,
    graph_value: dict[str, Any],
    state_path: Path,
    state_value: dict[str, Any],
) -> None:
    """Publish a new graph/state pair, rolling back if either promotion fails."""

    import os
    import tempfile

    graph_target = graph_path.resolve()
    state_target = state_path.resolve()
    if os.path.normcase(str(graph_target)) == os.path.normcase(str(state_target)):
        raise WorkflowError("convergence graph and state outputs must be different paths")
    if graph_target.exists() or state_target.exists():
        raise WorkflowError("convergence outputs must not already exist")
    graph_target.parent.mkdir(parents=True, exist_ok=True)
    state_target.parent.mkdir(parents=True, exist_ok=True)
    staged: list[Path] = []
    promoted: list[Path] = []
    try:
        for target, value in ((graph_target, graph_value), (state_target, state_value)):
            descriptor, temporary = tempfile.mkstemp(
                prefix=f".{target.name}.", suffix=".tmp", dir=target.parent
            )
            os.close(descriptor)
            staged_path = Path(temporary)
            staged.append(staged_path)
            staged_path.write_text(
                json.dumps(value, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
                newline="\n",
            )
        for temporary, target in zip(staged, (graph_target, state_target), strict=True):
            os.replace(temporary, target)
            promoted.append(target)
    except OSError as exc:
        for target in reversed(promoted):
            try:
                target.unlink(missing_ok=True)
            except OSError:
                pass
        raise WorkflowError(
            f"convergence pair publication failed and was rolled back: {exc}"
        ) from exc
    finally:
        for temporary in staged:
            temporary.unlink(missing_ok=True)


def _converge(args: argparse.Namespace) -> dict[str, Any]:
    graph = _graph(args.graph)
    state = StateStore(args.state).load(graph)
    with open(args.findings, encoding="utf-8-sig") as handle:
        findings = json.load(handle)
    amended, migrated = converge(graph, state, findings)
    _publish_new_json_pair(
        Path(args.output_graph), amended.to_dict(), Path(args.output_state), migrated.to_dict()
    )
    return {
        "schemaVersion": 1,
        "workflowId": amended.workflow_id,
        "previousGraphDigest": graph.digest,
        "graphDigest": amended.digest,
        "addedTaskCount": len(amended.tasks) - len(graph.tasks),
        "outputGraph": str(Path(args.output_graph).resolve()),
        "outputState": str(Path(args.output_state).resolve()),
    }


def _verify_execution(args: argparse.Namespace) -> dict[str, Any]:
    graph = _graph(args.graph)
    store = StateStore(args.state)
    state = store.load(graph)
    with Path(args.report).open(encoding="utf-8-sig") as handle:
        report = json.load(handle)
    if not isinstance(report, dict) or report.get("schemaVersion") != 2:
        raise WorkflowError("verification report schemaVersion must be 2")
    bindings = {
        "workflowId": graph.workflow_id,
        "executionId": state.execution_id,
        "graphDigest": graph.digest,
    }
    mismatches = [name for name, value in bindings.items() if report.get(name) != value]
    if mismatches:
        raise WorkflowError("verification report identity mismatch: " + ", ".join(mismatches))
    previous = state.revision
    changed_paths = report.get("changedPaths", [])
    if not isinstance(changed_paths, list) or any(
        not isinstance(item, str) for item in changed_paths
    ):
        raise WorkflowError("verification report changedPaths must be an array of strings")
    invalidated = state.invalidate_verification(graph, changed_paths)
    state.record_verification(
        passed=report.get("passed") is True,
        evidence=report.get("evidence", ""),
        diff_digest=report.get("diffDigest", ""),
        independent=report.get("independent") is True,
    )
    store.save(state, expected_revision=previous)
    return {
        "schemaVersion": 2,
        "status": state.overall_status,
        "verificationStatus": state.verification_status,
        "invalidatedTasks": list(invalidated),
        "revision": state.revision,
    }


def _replan(args: argparse.Namespace) -> dict[str, Any]:
    graph = _graph(args.graph)
    state = StateStore(args.state).load(graph)
    tasks_path = Path(args.tasks)
    with Path(args.findings).open(encoding="utf-8-sig") as handle:
        findings = json.load(handle)
    with Path(args.route).open(encoding="utf-8-sig") as handle:
        route = json.load(handle)
    markdown, amended, migrated = replan_canonical(
        tasks_path.read_text(encoding="utf-8-sig"), graph, state, findings, route
    )
    Path(args.output_tasks).write_text(markdown, encoding="utf-8", newline="\n")
    write_compiled_graph(Path(args.output_graph), amended.to_dict())
    StateStore(args.output_state).save(migrated)
    return {
        "schemaVersion": 2,
        "workflowId": amended.workflow_id,
        "graphDigest": amended.digest,
        "convergenceRound": len(migrated.convergence_history),
        "taskCount": len(amended.tasks),
    }


def _migrate(args: argparse.Namespace) -> dict[str, Any]:
    graph_path = Path(args.graph)
    state_path = Path(args.state)
    output_graph = Path(args.output_graph)
    output_state = Path(args.output_state)
    for output in (output_graph, output_state):
        if output.exists():
            raise WorkflowError(f"migration output already exists: {output}")
    graph_bytes = graph_path.read_bytes()
    state_bytes = state_path.read_bytes()
    graph_document = json.loads(graph_bytes.decode("utf-8-sig"))
    state_document = json.loads(state_bytes.decode("utf-8-sig"))
    route = json.loads(Path(args.route).read_text(encoding="utf-8-sig"))
    markdown = Path(args.tasks).read_text(encoding="utf-8-sig")
    new_graph, new_state = migrate_v1(markdown, route, graph_document, state_document)
    write_migration_bundle(Path(args.backup), graph_bytes, state_bytes, new_graph, new_state)
    write_compiled_graph(output_graph, new_graph.to_dict())
    StateStore(output_state).save(new_state)
    return {
        "schemaVersion": 2,
        "status": "MIGRATED",
        "graphDigest": new_graph.digest,
        "executionId": new_state.execution_id,
        "backup": str(Path(args.backup)),
    }


def _benchmark(args: argparse.Namespace) -> dict[str, Any]:
    with open(args.input, encoding="utf-8-sig") as handle:
        return compare_runs(json.load(handle))


def _benchmark_run(args: argparse.Namespace) -> dict[str, Any]:
    recorded = record_control_loop_benchmark(args.samples)
    output = Path(args.output)
    if output.exists() and not args.force:
        raise WorkflowError(f"benchmark output already exists: {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(recorded, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    result = compare_runs(recorded)
    result["output"] = str(output)
    return result


def _run(args: argparse.Namespace) -> dict[str, Any]:
    with open(args.results, encoding="utf-8-sig") as handle:
        runtime = RecordedHostRuntime(json.load(handle))
    graph = _graph(args.graph)
    report = Orchestrator(graph, args.adapter).run_persisted_wave(StateStore(args.state), runtime)
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

    compile_command = commands.add_parser(
        "compile", help="compile canonical tasks Markdown using a validated UEEF route"
    )
    compile_command.add_argument("--tasks", required=True)
    compile_command.add_argument("--workflow-id", required=True)
    compile_command.add_argument("--route", required=True)
    compile_command.add_argument("--output", required=True)
    compile_command.add_argument("--max-workers", type=int)
    compile_command.add_argument("--check", action="store_true")
    compile_command.set_defaults(handler=_compile)

    initialize = commands.add_parser("init", help="initialize execution state")
    initialize.add_argument("--graph", required=True)
    initialize.add_argument("--state", required=True)
    initialize.add_argument("--force", action="store_true")
    initialize.add_argument("--current-execution-id")
    initialize.add_argument("--current-revision", type=int)
    initialize.set_defaults(handler=_init)

    status = commands.add_parser("status", help="read and validate resumable state")
    status.add_argument("--graph", required=True)
    status.add_argument("--state", required=True)
    status.set_defaults(handler=_status)

    pause = commands.add_parser("pause", help="operator-pause new workflow reservations")
    pause.add_argument("--graph", required=True)
    pause.add_argument("--state", required=True)
    pause.add_argument("--reason", required=True)
    pause.set_defaults(handler=_pause)

    resume = commands.add_parser("resume", help="resume an operator-paused workflow")
    resume.add_argument("--graph", required=True)
    resume.add_argument("--state", required=True)
    resume.set_defaults(handler=_resume)

    prepare = commands.add_parser("prepare", help="validate the authored lifecycle and compile")
    prepare.add_argument("--root", required=True)
    prepare.add_argument("--workflow-id", required=True)
    prepare.add_argument("--route", required=True)
    prepare.add_argument("--output")
    prepare.set_defaults(handler=_prepare)

    hierarchy = commands.add_parser("hierarchy", help="validate and roll up feature hierarchy")
    hierarchy.add_argument("--input", required=True)
    _add_trust_options(hierarchy)
    hierarchy.set_defaults(handler=_hierarchy)

    customizations = commands.add_parser(
        "resolve-customizations", help="resolve permission-clamped extension manifests"
    )
    customizations.add_argument("--input", required=True)
    customizations.add_argument("--route", required=True)
    customizations.set_defaults(handler=_customizations)

    catalog_query = commands.add_parser(
        "catalog-query", help="list, search, or inspect governed catalog entries"
    )
    catalog_query.add_argument("--catalog", required=True)
    catalog_query.add_argument("--action", required=True, choices=("list", "search", "info"))
    catalog_query.add_argument("--term")
    catalog_query.add_argument("--target")
    catalog_query.set_defaults(handler=_catalog_query)

    catalog_registry = commands.add_parser(
        "catalog-registry", help="manage local catalog sources and selections atomically"
    )
    catalog_registry.add_argument("--catalog", required=True)
    catalog_registry.add_argument("--registry", required=True)
    catalog_registry.add_argument(
        "--action",
        required=True,
        choices=(
            "init", "validate", "reconcile", "enable", "disable", "priority",
            "select", "unselect",
        ),
    )
    catalog_registry.add_argument("--target")
    catalog_registry.add_argument("--priority", type=int)
    catalog_registry.set_defaults(handler=_catalog_registry)

    catalog_build = commands.add_parser(
        "catalog-build", help="build a route-clamped plan from the governed local registry"
    )
    catalog_build.add_argument("--catalog", required=True)
    catalog_build.add_argument("--registry", required=True)
    catalog_build.add_argument("--route", required=True)
    catalog_build.set_defaults(handler=_catalog_build)

    catalog_maintain = commands.add_parser(
        "catalog-maintain",
        help="CAS-update local source or item metadata without fetching or executing content",
    )
    catalog_maintain.add_argument("--catalog", required=True)
    catalog_maintain.add_argument(
        "--action",
        required=True,
        choices=(
            "add-source", "update-source", "remove-source",
            "add-item", "update-item", "remove-item",
        ),
    )
    catalog_maintain.add_argument("--target")
    catalog_maintain.add_argument("--source-id")
    catalog_maintain.add_argument("--record")
    catalog_maintain.add_argument("--expected-digest", required=True)
    catalog_maintain.set_defaults(handler=_catalog_maintain)

    expand_workflow = commands.add_parser(
        "expand-workflow", help="expand bounded declarative workflow constructs"
    )
    expand_workflow.add_argument("--input", required=True)
    expand_workflow.add_argument("--context")
    expand_workflow.set_defaults(handler=_expand_workflow)

    hosts = commands.add_parser("host-status", help="report runtime versus contract host status")
    hosts.add_argument("--evidence", help="current host verification evidence")
    hosts.set_defaults(handler=_host_status)

    schedule = commands.add_parser("schedule", help="recommend and persist the next wave")
    schedule.add_argument("--graph", required=True)
    schedule.add_argument("--state", required=True)
    schedule.add_argument("--adapter", default="generic", choices=("generic", "codex", "claude"))
    schedule.add_argument("--approvals")
    schedule.add_argument("--require-approval-risk", type=int, default=4, choices=range(0, 5))
    _add_trust_options(schedule)
    schedule.set_defaults(handler=_schedule)

    pending = commands.add_parser(
        "pending-contracts", help="rebuild dispatch contracts for persisted reservations"
    )
    pending.add_argument("--graph", required=True)
    pending.add_argument("--state", required=True)
    pending.add_argument("--adapter", default="generic", choices=("generic", "codex", "claude"))
    pending.add_argument("--approvals")
    pending.add_argument("--require-approval-risk", type=int, default=4, choices=range(0, 5))
    _add_trust_options(pending)
    pending.set_defaults(handler=_pending_contracts)

    commit_staged = commands.add_parser(
        "commit-staged-reservation",
        help="atomically promote a staged reservation after host receipt verification",
    )
    commit_staged.add_argument("--graph", required=True)
    commit_staged.add_argument("--state", required=True)
    commit_staged.add_argument("--staged", required=True)
    commit_staged.add_argument("--allow-create", action="store_true")
    commit_staged.set_defaults(handler=_commit_staged_reservation)

    approval_status = commands.add_parser(
        "approval-status", help="verify an identity-bound human approval gate"
    )
    approval_status.add_argument("--graph", required=True)
    approval_status.add_argument("--state", required=True)
    approval_status.add_argument("--approvals", required=True)
    approval_status.add_argument("--task", required=True)
    _add_trust_options(approval_status)
    approval_status.set_defaults(handler=_approval_status)

    approval_record = commands.add_parser(
        "approval-record", help="append a signed approval decision to the durable ledger"
    )
    approval_record.add_argument("--graph", required=True)
    approval_record.add_argument("--state", required=True)
    approval_record.add_argument("--approvals", required=True)
    approval_record.add_argument("--task", required=True)
    approval_record.add_argument("--gate", required=True)
    approval_record.add_argument("--identity", required=True)
    approval_record.add_argument("--role", required=True)
    approval_record.add_argument("--action", required=True, choices=("GRANT", "REVOKE"))
    approval_record.add_argument("--evidence-digest", required=True)
    approval_record.add_argument("--key-id")
    _add_trust_options(approval_record)
    approval_record.set_defaults(handler=_approval_record)

    compose = commands.add_parser(
        "compose-templates", help="compose declarative template layers deterministically"
    )
    for layer in ("core", "extension", "preset", "project"):
        compose.add_argument(f"--{layer}")
    compose.add_argument("--output")
    compose.set_defaults(handler=_compose_templates)

    install = commands.add_parser(
        "package-install", help="stage and verify a content-addressed package"
    )
    install.add_argument("--store", required=True)
    install.add_argument("--name", required=True)
    install.add_argument("--version", required=True)
    install.add_argument("--source", required=True)
    install.add_argument("--expected-digest")
    install.add_argument("--metadata")
    _add_trust_options(install)
    install.set_defaults(handler=_package_install)

    install_composition = commands.add_parser(
        "package-install-composition",
        help="compose multiple layers and install the verified content-addressed result",
    )
    install_composition.add_argument("--store", required=True)
    install_composition.add_argument("--name", required=True)
    install_composition.add_argument("--version", required=True)
    for layer in ("core", "extension", "preset", "project"):
        install_composition.add_argument(f"--{layer}")
    install_composition.add_argument("--metadata")
    install_composition.add_argument("--expected-digest")
    _add_trust_options(install_composition)
    install_composition.set_defaults(handler=_package_install_composition)

    activate = commands.add_parser(
        "package-activate", help="atomically activate a verified package"
    )
    activate.add_argument("--store", required=True)
    activate.add_argument("--name", required=True)
    activate.add_argument("--version", required=True)
    activate.add_argument("--digest", required=True)
    _add_trust_options(activate)
    activate.set_defaults(handler=_package_activate)

    rollback = commands.add_parser(
        "package-rollback", help="atomically roll back an active package"
    )
    rollback.add_argument("--store", required=True)
    rollback.add_argument("--name", required=True)
    _add_trust_options(rollback)
    rollback.set_defaults(handler=_package_rollback)

    portfolio = commands.add_parser(
        "portfolio-status", help="orchestrate identity-bound feature workflows"
    )
    portfolio.add_argument("--portfolio", required=True)
    portfolio.add_argument("--observed", required=True)
    portfolio.set_defaults(handler=_portfolio_status)

    control = commands.add_parser(
        "control-status", help="report truthful workflow, approval, and Codex readiness"
    )
    control.add_argument("--graph", required=True)
    control.add_argument("--state", required=True)
    control.add_argument("--approvals")
    control.add_argument("--host-evidence")
    control.add_argument("--portfolio")
    control.add_argument("--observed")
    control.add_argument("--supply-chain")
    _add_trust_options(control)
    control.set_defaults(handler=_control_status)

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

    verify_execution = commands.add_parser(
        "verify", help="apply an independent identity-bound verification report"
    )
    verify_execution.add_argument("--graph", required=True)
    verify_execution.add_argument("--state", required=True)
    verify_execution.add_argument("--report", required=True)
    verify_execution.set_defaults(handler=_verify_execution)

    replan = commands.add_parser(
        "replan", help="append verifier findings to the canonical plan and compile a new generation"
    )
    replan.add_argument("--tasks", required=True)
    replan.add_argument("--graph", required=True)
    replan.add_argument("--state", required=True)
    replan.add_argument("--findings", required=True)
    replan.add_argument("--route", required=True)
    replan.add_argument("--output-tasks", required=True)
    replan.add_argument("--output-graph", required=True)
    replan.add_argument("--output-state", required=True)
    replan.set_defaults(handler=_replan)

    migrate = commands.add_parser(
        "migrate", help="non-destructively migrate v1 graph/state artifacts to compiled v2"
    )
    migrate.add_argument("--tasks", required=True)
    migrate.add_argument("--graph", required=True)
    migrate.add_argument("--state", required=True)
    migrate.add_argument("--route", required=True)
    migrate.add_argument("--output-graph", required=True)
    migrate.add_argument("--output-state", required=True)
    migrate.add_argument("--backup", required=True)
    migrate.set_defaults(handler=_migrate)

    benchmark = commands.add_parser(
        "benchmark", help="compare recorded single, static, and dynamic runs"
    )
    benchmark.add_argument("--input", required=True)
    benchmark.set_defaults(handler=_benchmark)

    benchmark_run = commands.add_parser(
        "benchmark-run", help="record the local control-loop recovery microbenchmark"
    )
    benchmark_run.add_argument("--output", required=True)
    benchmark_run.add_argument("--samples", type=int, default=5)
    benchmark_run.add_argument("--force", action="store_true")
    benchmark_run.set_defaults(handler=_benchmark_run)

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
