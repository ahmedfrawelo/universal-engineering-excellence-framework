# Runtime Activation Proof

Version: 1.0
Pack: 01-core
Status: Stable
Applies To: all engineering tasks

## Purpose

This module proves whether UEEF is being used as a runtime operating system without requiring the full framework to be loaded.

## Required Proof

An AI assistant may claim UEEF is active only when all of these are true:

- UEEF runtime path exists.
- `framework/01-core/00-boot-loader.md` exists and is loaded.
- `framework/01-core/00-core-system.md` exists and is loaded.
- `framework/01-core/01-master-loader.md` exists and is used only as a selector for normal tasks.
- Relevant task modules are explicitly selected.
- Relevant quality gates are selected.
- MCPs, tools, connectors, local scripts, and installed skills are checked.
- UI UX Pro Max is checked and applied when UI work is involved.

## Compact Runtime Check

```text
UEEF: ACTIVE / INACTIVE
Loaded: boot-loader, core-system
Selected: <module paths or count>
Gates: <gate paths or count>
UIUX: YES / NO / NA
Status: READY / BLOCKED
```

## Failure Conditions

- `Loaded` lists the full framework for a normal coding task.
- `Loaded` lists `master-loader`, `master-index`, `runtime-sequence`, or `activation proof` as always-loaded modules.
- Relevant modules or gates are not selected.
- UI UX Pro Max is skipped for UI work.
