# UEEF Required Preflight

Version: 1.0
Pack: 01-core
Status: Stable
Applies To: every non-trivial engineering task

## Mandatory Rule

Before every non-trivial engineering task, the AI must run a UEEF Preflight Check. The AI must not start implementation until it can produce:

`	ext
UEEF Active: YES
`

If UEEF cannot be verified, the AI must report:

`	ext
UEEF Active: NO
Reason:
Required action:
`

The AI must not pretend UEEF is active.

## Preflight Procedure

1. Locate UEEF in the repository or global install path.
2. Load the core system, master loader, master index, runtime sequence, and activation proof.
3. Detect project stack, architecture, tools, MCPs, connectors, scripts, installed skills, and package managers.
4. Select relevant UEEF modules for the task.
5. Decide whether UI UX Pro Max is required.
6. Plan the quality gates that must pass before final response.
7. Emit the UEEF Runtime Check block.

## Blocking Rule

If the runtime check status is BLOCKED, do not edit project files. Report the missing evidence and the smallest corrective action.

## Final Response Rule

Every completed task must include UEEF verification evidence:

## UEEF Verification

UEEF Active:
Core Modules Loaded:
Relevant Modules Used:
Quality Gates Applied:
MCPs / Tools Checked:
Skills Checked:
UI UX Pro Max Applied:
Activation Gate:
