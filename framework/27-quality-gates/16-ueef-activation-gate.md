# UEEF Activation Gate

Version: 1.0
Pack: 27-quality-gates
Status: Stable
Applies To: every task before implementation and before final response

## Purpose

This gate prevents fake activation claims. A task is incomplete if UEEF was not loaded, checked, and applied with evidence.

## Gate Checks

- UEEF global path or repository path exists.
- Core System file exists: ramework/01-core/00-core-system.md.
- Master Loader file exists: ramework/01-core/01-master-loader.md.
- Master Index file exists: ramework/01-core/02-master-index.md or ramework/MASTER_INDEX.md.
- Runtime sequence exists: ramework/03-runtime/00-runtime-sequence.md.
- Runtime activation proof exists: ramework/01-core/10-runtime-activation-proof.md.
- Relevant modules were selected for the task.
- MCPs, tools, connectors, local scripts, and installed skills were checked.
- UI UX Pro Max was checked for UI, UX, frontend, design, layout, or accessibility work.
- Quality Gates were planned before implementation.
- Final response includes UEEF verification evidence.

## Failure Conditions

This gate fails if:

- UEEF global path is missing and no repository fallback is verified.
- Core System file is missing.
- Master Loader file is missing.
- Master Index file is missing.
- Runtime sequence is missing.
- Relevant modules were not selected.
- MCPs, tools, or installed skills were ignored.
- UI UX Pro Max was not checked for UI tasks.
- Quality Gates were skipped.
- Final response does not include UEEF verification evidence.

## Pass Criteria

The gate passes only when the runtime check block is complete, status is READY, and the final response reports UEEF Active status, core modules loaded, relevant modules used, quality gates applied, MCPs/tools checked, skills checked, UI UX Pro Max status, and this activation gate result.

## Required Evidence

- Status script output or direct file inspection.
- Exact selected module paths.
- Exact quality gate paths.
- Tool and skill availability notes.
- Final verification block.
