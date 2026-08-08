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
