# Task Plan Template

Version: 1.1
Pack: 21-framework-resources/01-templates
Status: Stable
Applies To: implementation work with multiple dependent steps or material risk

## Outcome

- Requested end state:
- Observable acceptance criteria:
- Explicit exclusions:
- Owner or decision-maker:

## Inspected Context

- Repository and affected boundaries:
- Existing conventions and reusable mechanisms:
- Constraints, dependencies, and user-owned changes:
- Unknowns that could change the plan:

## Route

- Complexity tier and evidence:
- Required skills, tools, modules, and quality gates:
- Parallelization decision and reason:
- Browser or external-system requirement and reason:

## Steps

| Order | Step and deliverable | Dependencies | Verification | Status |
| --- | --- | --- | --- | --- |
| 1 |  |  |  | Pending |
| 2 |  |  |  | Pending |
| 3 |  |  |  | Pending |

Only one dependent step may be `In progress` at a time. Independent steps may run concurrently when the execution policy permits it.

## Goal Update Register

| Update ID | Summary | Relation | Current/resume point | Target step | Order | Dependencies | Acceptance criteria | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| GU-1 |  | CURRENT_STEP / PRIOR_STEP_CORRECTION / FUTURE_STEP / INVALIDATES_CURRENT_WORK / CONFLICT_OR_AMBIGUOUS |  |  |  |  |  | Pending |

Route every new user goal update before changing execution. Merge `CURRENT_STEP` updates into the active step. For `PRIOR_STEP_CORRECTION`, save the current resume point, verify the reopened step, then restore the interrupted step. Queue `FUTURE_STEP` updates with explicit order, dependencies, and acceptance criteria while preserving current work. Pause and replan only when an update invalidates current work; preserve state and ask the user when requirements conflict or remain materially ambiguous.

## Risk Controls

- Destructive or externally visible actions:
- Security, privacy, data, compatibility, and production risks:
- Rollback or recovery path:
- Approval or authority boundaries:

## Evidence Log

| Acceptance criterion | Actual implementation/behavior | Evidence source | Result | Remaining gap |
| --- | --- | --- | --- | --- |
|  |  |  |  |  |

## Completion Audit

- Every requested outcome maps to a completed step and evidence row.
- Every actual implementation item maps back to a requirement; no untraced implementation remains.
- Required gates passed; failures and skips were not hidden.
- Runtime or published artifacts were synchronized when in scope.
- Residual limitations have an owner and next action.
- Final status is `COMPLETE`, `BLOCKED`, or `PARTIAL` with an evidence-backed reason.
