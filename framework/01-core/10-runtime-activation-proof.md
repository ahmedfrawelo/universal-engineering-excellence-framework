# Runtime Activation Proof

Version: 1.0
Pack: 01-core
Status: Stable
Applies To: all engineering tasks

## Purpose

This module proves whether UEEF is being used as a runtime operating system instead of existing only as repository documentation. It defines the evidence an AI assistant must gather before starting implementation.

## Required Proof

An AI assistant may claim UEEF is active only when all of these are true:

- A UEEF repository or global installation path exists.
- ramework/01-core/00-core-system.md exists and was loaded.
- ramework/01-core/01-master-loader.md exists and was loaded.
- ramework/01-core/02-master-index.md or ramework/MASTER_INDEX.md exists and was used for module selection.
- ramework/03-runtime/00-runtime-sequence.md exists and controls task order.
- ramework/27-quality-gates/16-ueef-activation-gate.md exists and passes.
- Relevant modules are explicitly selected for the current task.
- MCPs, tools, connectors, local scripts, and installed skills are checked.
- UI UX Pro Max is checked and applied when UI work is involved.
- Planned quality gates are named before implementation.

## Runtime Check Block

## UEEF Runtime Check

UEEF Active: YES / NO

Global UEEF Path:
...

UEEF Version:
...

Core Loaded:
- framework/01-core/00-core-system.md
- framework/01-core/01-master-loader.md
- framework/01-core/02-master-index.md

Relevant Modules Selected:
- ...

MCPs Checked:
- ...

Skills Checked:
- ...

UI UX Pro Max:
Required: YES / NO
Available: YES / NO / UNKNOWN
Applied: YES / NO / NOT APPLICABLE

Quality Gates Planned:
- ...

Status:
READY / BLOCKED

## Evidence Rules

- Do not write UEEF Active: YES from memory or intent.
- Use direct file inspection, a status script result, or a verified global loader path.
- If evidence is missing, write UEEF Active: NO and explain the required action.
- If status is BLOCKED, do not edit project files until activation is restored or the user explicitly accepts work without UEEF.

## Pass Criteria

This proof passes when the runtime check block is complete, the activation gate passes, and the final response includes UEEF verification evidence.
