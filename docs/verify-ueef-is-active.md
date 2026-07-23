# Verify UEEF Is Active

## Purpose

This document explains how to prove UEEF is installed, global, active, and token-efficient.

## Verify Status

Run from the runtime or repository:

```powershell
.\scripts\ueef-status.ps1
```

Required result:

```text
Overall: ACTIVE
```

## Verify Runtime Location

UEEF must run from Codex home:

```text
`$CODEX_HOME/ueef/codex` (defaults to `E:\shared folder\codex-home` when `CODEX_HOME` is unset)
```

The old home runtime must be absent:

```text
C:\Users\ahmed\.ueef = absent
```

## Valid Compact Runtime Check

```text
UEEF: ACTIVE
Loaded: boot-loader, core-system
Selected: <task-specific module paths or count>
Gates: <task-specific gates>
UIUX: YES / NO / NA
Status: READY
```

## Detect Fake Or Old Activation

Activation is fake or outdated when final output says:

```text
Do not use the old verbose Loaded modules line with selector/runtime files.
```

Correct behavior: `master-loader` is a selector; it belongs under `Selected` only when relevant, not under `Loaded`.

## If UEEF Is Inactive

Run:

```powershell
.\scripts\sync-runtime.ps1
.\scripts\ueef-status.ps1
.\scripts\check-runtime-drift.ps1
```
