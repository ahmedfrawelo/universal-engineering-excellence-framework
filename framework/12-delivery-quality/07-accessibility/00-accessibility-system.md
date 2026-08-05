# Accessibility

Version: 1.0
Pack: 12-delivery-quality/07-accessibility
Status: Stable
Applies To: tasks where accessibility materially affects the outcome

## Purpose

This module establishes the enforceable **accessibility** contract for perceivable, operable, understandable, and robust experiences. It exists to turn that concern into explicit decisions, safeguards, and completion evidence.

## Apply When

- The request names accessibility or changes behavior governed by it.
- Repository inspection finds an affected boundary, convention, artifact, or risk.
- A reviewer cannot prove the outcome without making the accessibility decision explicit.

## Required Decisions

1. State the observable outcome and owner for accessibility.
2. Support semantic structure, keyboard operation, focus, zoom, and assistive technology.
3. Record assumptions, rejected alternatives, and the condition that would require revisiting the decision.

## Mandatory Safeguards

- Accessibility cannot be deferred to visual polish or automated scans alone.
- Reuse the repository's existing owner, pattern, and automation before adding a parallel mechanism.
- Keep failure behavior explicit, bounded, diagnosable, and recoverable in proportion to risk.

## Required Evidence

- Direct evidence that the accessibility outcome works in the changed context.
- automated checks plus keyboard and screen-reader-oriented manual evidence.
- A focused regression check for the nearest behavior that could be broken.

## Failure Conditions

- The accessibility decision is implicit, ownerless, or contradicted by the implementation.
- Evidence demonstrates only intent, compilation, or a happy path when stronger proof is practical.
- Residual risk is hidden, unbounded, or handed off without an owner and trigger.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../12-delivery-quality/04-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
