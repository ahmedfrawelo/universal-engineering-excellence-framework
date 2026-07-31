# Runtime Hardening

## Purpose

This document defines how UEEF stays active inside the Codex runtime, how drift is detected, and how quality gates are selected before implementation.

## Runtime Location

The active runtime must live under Codex home:

```text
CODEX_HOME/ueef/codex
```

On this machine the active path is:

```text
`$CODEX_HOME/ueef/codex` (defaults to `E:\shared folder\codex-home` when `CODEX_HOME` is unset)
```

UEEF must not depend on `$HOME/.ueef` for Codex runtime activation.

## Sync Runtime

Run:

```powershell
.\scripts\sync-runtime.ps1
```

The sync script creates a self-contained runtime copy, writes `UEEF-LOADER.md`, updates `CODEX_HOME/AGENTS.md`, and writes `UEEF-ACTIVE.json`.

## Drift Check

Run:

```powershell
.\scripts\check-runtime-drift.ps1
```

The drift check compares critical files between the source repository and Codex runtime. `Overall: SYNCED` is required before claiming runtime parity.

## Active State

`UEEF-ACTIVE.json` records version, runtime path, source commit, loader path, AGENTS path, old HOME `.ueef` state, and required check results.

## Quality Gate Selector

Run:

```powershell
.\scripts\select-quality-gates.ps1 -Task "frontend UI task"

# Explainable cross-platform frontend routing
.\scripts\select-frontend-route.ps1 -Task "Fix dropdown focus" -Json
# Unix: ./scripts/select-frontend-route.sh "Fix dropdown focus"
```

The selector prints relevant modules, required quality gates, UI UX Pro Max status, and the activation gate.

## Task-routing performance ledger

Task routing is measured in one warm PowerShell process with seven samples per case. Medians are the decision metric; direct route and status timings act as controls. The 2026-07-31 optimization preserved the canonical route object from classification through capability-profile and quality-gate selection instead of launching the Node route engine twice.

| Case | Before median | After median | Result |
| --- | ---: | ---: | --- |
| Direct frontend route | 60.7 ms | 54.5 ms | Control; no attributed optimization claim |
| Task classification | 67.4 ms | 62.1 ms | Control; within normal process-start variance |
| Quality-gate selection | 162.5 ms | 63.9 ms | Kept; 60.7% lower median |
| Capability profile | 132.9 ms | 137.1 ms | Neutral control; within process-start variance |
| Task preflight without health probe | 228.3 ms | 155.7 ms | Kept; 31.8% lower median |
| Runtime status without drift scan | 72.4 ms | 71.2 ms | Control; unchanged |

The preflight regression test also replaces `node` with a counting pass-through shim and requires exactly one real route-engine invocation. Correctness tests must pass before timing evidence is accepted.
## Exact Codex installation

For Codex, UEEF installs exactly into the active Codex runtime. `CODEX_HOME` is required. The installer must create:

- `CODEX_HOME/AGENTS.md`
- `CODEX_HOME/ueef/codex`
- `CODEX_HOME/ueef/codex/UEEF-LOADER.md`
- `CODEX_HOME/ueef/UEEF-ACTIVE.json`

If `CODEX_HOME` is missing, `scripts/install-codex.ps1` and `scripts/install-codex.sh` must fail instead of installing to a fallback path.
