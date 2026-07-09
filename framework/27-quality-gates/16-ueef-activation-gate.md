# UEEF Activation Gate

Version: 1.0
Pack: 27-quality-gates
Status: Stable
Applies To: every task before implementation and before final response

## Purpose

This gate prevents fake activation claims. A task is incomplete if UEEF was not loaded, checked, and applied with evidence.

## Gate Checks

- UEEF global path or repository path exists.
- Core System file exists: framework/01-core/00-core-system.md.
- Master Loader file exists: framework/01-core/01-master-loader.md.
- Master Index file exists: framework/01-core/02-master-index.md or framework/MASTER_INDEX.md.
- Runtime sequence exists: framework/03-runtime/00-runtime-sequence.md.
- Runtime activation proof exists: framework/01-core/10-runtime-activation-proof.md.
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
- The final response `Loaded` line contains anything except `boot-loader, core-system`.

## Pass Criteria

The gate passes only when the runtime check block is complete, status is READY, and the final response uses the compact UEEF Verification fields: `UEEF`, `Loaded`, `Selected`, `Gates`, `Tools`, `Skills`, `UIUX`, and `Status`.

The `Loaded` field must only report always-loaded runtime modules: `boot-loader, core-system`. Selector, index, runtime-sequence, and activation-proof files belong under `Selected` or `Gates` when relevant, never under `Loaded`.

This gate fails if `Loaded` contains `loader`, `UEEF-LOADER`, `AGENTS`, `master-loader`, `master-index`, `runtime-sequence`, or `activation-proof`.

## Required Evidence

- Status script output or direct file inspection.
- Exact selected module paths.
- Exact quality gate paths.
- Tool and skill availability notes.
- Final verification block.
