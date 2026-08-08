# UEEF Spec Workflow Engine

This engine turns UEEF specification tasks into a validated dependency graph,
persists execution state, and recommends conflict-free execution waves whose
worker count grows or shrinks with the ready work.

## Ownership boundary

- `upstream/spec-kit/` is an unmodified source snapshot of GitHub Spec Kit
  `v0.16.1` at commit `ad4104b56c219b0a27bac06547d1a3c7d6a0dbd6`.
- `UPSTREAM.json` records its provenance and aggregate digest.
- `ueef/ueef_spec_workflow/` is UEEF-owned policy, state, scheduling, adapter,
  and CLI code.
- No command in the UEEF CLI executes an upstream shell step. Upstream workflow
  validation rejects shell steps by default and execution remains host-owned.

## Core flow

```text
spec artifacts -> task-graph.json -> validate -> initialize state
              -> schedule a wave -> host dispatch -> transition results
              -> persist/resume -> converge
```

Use the repository wrapper so the package does not need to be installed:

```powershell
scripts\invoke-spec-workflow-engine.ps1 validate --graph .ueef\specs\demo\task-graph.json
scripts\invoke-spec-workflow-engine.ps1 init --graph .ueef\specs\demo\task-graph.json --state .ueef\specs\demo\execution-state.json
scripts\invoke-spec-workflow-engine.ps1 schedule --graph .ueef\specs\demo\task-graph.json --state .ueef\specs\demo\execution-state.json --adapter codex
```

The scheduler is deliberately a planner and state machine, not a hidden agent
launcher. It atomically marks emitted work `RESERVED`; the host confirms it
with `start` or returns it with `release`. Host adapters emit bounded dispatch
contracts including ownership, write scopes, dependencies, and acceptance
evidence. The active host remains responsible for creating workers and
returning their results.

## Host orchestration and convergence

`ueef_spec_workflow.orchestration.Orchestrator` consumes a scheduled wave
through an explicit `HostRuntime` implementation. Codex contracts declare the
`codex-thread` transport, Claude contracts declare `claude-agent-team`, and all
hosts return the bounded `ueef-host-result/v1` protocol. The engine never
launches a shell or silently creates a worker.

Persisted execution also writes an append-only, fsync-backed
`<execution-state>.events.jsonl` file. It records the reservation, every host
start, and every host result with the state revision, so a human or host can
audit a resume without treating mutable state as the only history.

For an explicit host hand-off, let the host produce a bounded result receipt,
then persist the wave. `run` never launches an agent or shell itself:

```powershell
scripts\invoke-spec-workflow-engine.ps1 run --graph task-graph.json --state execution-state.json --adapter codex --results host-results.json
```

`host-results.json` has schema version 1 and a `results` array with the exact
`taskId`, `worker`, `outcome`, evidence/error, and token count returned by the
host. A missing or mismatched receipt is recorded as a bounded failure.

For actual native-host dispatch, call `schedule` first, pass the emitted
contracts to the chosen Codex or Claude host, then apply its receipts without
re-scheduling or losing the reservation:

```powershell
scripts\invoke-spec-workflow-engine.ps1 apply-results --graph task-graph.json --state execution-state.json --adapter codex --results host-results.json
```

## Safe team-management cycle

`manage` supplies the missing live-management decision layer without crossing
the host boundary. Give it a non-executable worker catalog; it selects only
available workers whose declared capabilities satisfy each task, reports
reroute/escalation actions from persisted state, and holds `verifier` and
`integration` capability tasks until their prerequisite phases are complete.
It does not launch, terminate, inspect, or grant permissions to any agent.

```json
{
  "schemaVersion": 1,
  "workers": [
    {"id": "backend-1", "capabilities": ["backend"]},
    {"id": "reviewer-1", "capabilities": ["verifier"]},
    {"id": "integrator-1", "capabilities": ["integration"]}
  ]
}
```

Plan a cycle without changing state, then reserve precisely the emitted
contracts only after the host is ready to create those workers:

```powershell
scripts\invoke-spec-workflow-engine.ps1 manage --graph task-graph.json --state execution-state.json --workers host-workers.json --adapter codex
scripts\invoke-spec-workflow-engine.ps1 manage --graph task-graph.json --state execution-state.json --workers host-workers.json --adapter codex --commit
```

The append-only event log records every management cycle. A `REROUTE` action
means a prior bounded attempt failed but remains retryable; `ESCALATE_*` and
`WAIT_FOR_WORKER` require an explicit host or lead decision.

For Codex, `scripts\invoke-spec-workflow-codex-host.mjs` is the concrete App
Server bridge. It accepts one `codex-thread` dispatch contract on standard
input and a fresh UEEF route using `--route`. It dispatches through the existing
verified App Server route and returns only a validated result receipt. The host
is still explicit: callers choose the route, scope, sandbox, and when to run it.

For Claude Code, `scripts\invoke-spec-workflow-claude-host.mjs` uses the
official print-mode JSON contract: `claude -p --output-format json`. It accepts
one `claude-agent-team` contract on standard input and returns the same bounded
receipt format for `apply-results`. The bridge does not add dangerous permission
flags; the installed Claude Code configuration remains the authority for tool
permissions. Claude Code is not installed in this repository's verified runtime,
so this bridge is syntax- and contract-tested here but must be executed on a
configured Claude host before being called a verified runtime integration.

Verifier gaps can be added without rewriting completed work. The convergence
command requires traceable `sourceEvidence`, validates the amended DAG, and
writes new graph and state files so the old graph-bound state stays recoverable:

```powershell
scripts\invoke-spec-workflow-engine.ps1 converge --graph old-graph.json --state old-state.json --findings verifier-gaps.json --output-graph next-graph.json --output-state next-state.json
```

## Productivity benchmark

The benchmark command accepts recorded runs for `single-agent`, `ueef-static`,
and `dynamic-team`. It reports sample count, success rate, makespan, tokens,
retries, conflicts, and rework. It never invents timings or token counts:

Every comparison also declares one `scenarioId` and `workloadDigest`, and every
sample has a unique `runId`. This prevents different workloads from being
presented as one productivity comparison.

```powershell
scripts\invoke-spec-workflow-engine.ps1 benchmark --input recorded-runs.json
```
