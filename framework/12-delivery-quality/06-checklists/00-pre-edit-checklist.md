# pre edit checklist

Version: 1.0
Pack: 12-delivery-quality/06-checklists
Status: Stable
Applies To: tasks where pre edit checklist materially affects the outcome

## Purpose

This module establishes the enforceable **pre edit checklist** contract for ordered human verification for high-risk or non-automated concerns. It exists to turn that concern into explicit decisions, safeguards, and completion evidence.

## Apply When

- The request names pre edit checklist or changes behavior governed by it.
- Repository inspection finds an affected boundary, convention, artifact, or risk.
- A reviewer cannot prove the outcome without making the pre edit checklist decision explicit.

## Required Decisions

1. State the observable outcome and owner for pre edit checklist.
2. Keep items observable, action-oriented, and tied to a completion decision.
3. Record assumptions, rejected alternatives, and the condition that would require revisiting the decision.

## Mandatory Safeguards

- Do not mark unknown or untested items as complete.
- Reuse the repository's existing owner, pattern, and automation before adding a parallel mechanism.
- Keep failure behavior explicit, bounded, diagnosable, and recoverable in proportion to risk.

## Required Evidence

- Direct evidence that the pre edit checklist outcome works in the changed context.
- a checked record with exceptions, owner, and follow-up.
- A focused regression check for the nearest behavior that could be broken.

## Failure Conditions

- The pre edit checklist decision is implicit, ownerless, or contradicted by the implementation.
- Evidence demonstrates only intent, compilation, or a happy path when stronger proof is practical.
- Residual risk is hidden, unbounded, or handed off without an owner and trigger.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../12-delivery-quality/04-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
