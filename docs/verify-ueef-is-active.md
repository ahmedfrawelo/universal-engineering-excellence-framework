# Verify UEEF Is Active

## Purpose

This document explains how to prove UEEF is installed, global, active, and
token-efficient.

## Verify Status

Run from the runtime or repository:

```powershell
.\scripts\ueef-status.ps1
```

Required managed-runtime result:

```text
Installed: YES
Global loader: PASS
Overall: ACTIVE
```

`Mode: source-checkout` with `Overall: SOURCE_VALIDATED` proves that the
repository itself passes source checks. It is useful evidence for repository
maintenance, but it is not proof that an assistant is using the installed
runtime.

## Verify Runtime Location

UEEF must run from Codex home:

```text
$CODEX_HOME/ueef/codex
```

When `CODEX_HOME` is unset, it defaults to the platform's standard `.codex` directory.

The old home runtime must be absent:

```text
$HOME/.ueef = absent
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

Correct behavior: `master-loader` is a selector; it belongs under `Selected`
only when relevant, not under `Loaded`.

## If UEEF Is Inactive

Run:

```powershell
.\scripts\sync-runtime.ps1
.\scripts\ueef-status.ps1
.\scripts\check-runtime-drift.ps1
```

- Global loader exists or a required action is shown.
- Validation script exists.

## Interpretation

- `Overall: ACTIVE` means the managed runtime is installed and may be used for
  engineering work.
- `Overall: SOURCE_VALIDATED` means only that a source checkout passes
  repository validation.
- `Overall: INACTIVE` or `SOURCE_INVALID` means the assistant must not pretend
  UEEF is active.
- `Global loader: UNKNOWN` means the source repository is present but a global
  AI rules path was not verified.

## Required Response Behavior

If the status check is inactive, respond with:

```text
UEEF: INACTIVE
Reason:
Required action:
```

If the status is `SOURCE_VALIDATED`, say explicitly that the source is valid
but the managed runtime is not activated. If active, include the runtime check
block and continue with module selection.
