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
E:\shared folder\codex-home\ueef\codex
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
```

The selector prints relevant modules, required quality gates, UI UX Pro Max status, and the activation gate.
