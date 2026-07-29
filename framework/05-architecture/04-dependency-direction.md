# dependency direction

Version: 1.0  
Pack: 05-architecture  
Status: Stable  
Applies To: tasks where dependency direction materially affects the outcome

## Purpose

This module establishes the enforceable **dependency direction** contract for system boundaries, dependency direction, and architectural evolution. It exists to turn that concern into explicit decisions, safeguards, and completion evidence.

## Apply When

- The request names dependency direction or changes behavior governed by it.
- Repository inspection finds an affected boundary, convention, artifact, or risk.
- A reviewer cannot prove the outcome without making the dependency direction decision explicit.

## Required Decisions

1. State the observable outcome and owner for dependency direction.
2. Keep policy and domain decisions independent from delivery mechanisms.
3. Record assumptions, rejected alternatives, and the condition that would require revisiting the decision.

## Mandatory Safeguards

- Prevent dependency cycles and implicit ownership across module boundaries.
- Reuse the repository's existing owner, pattern, and automation before adding a parallel mechanism.
- Keep failure behavior explicit, bounded, diagnosable, and recoverable in proportion to risk.

## Required Evidence

- Direct evidence that the dependency direction outcome works in the changed context.
- a dependency or boundary view plus an ADR for material decisions.
- A focused regression check for the nearest behavior that could be broken.

## Failure Conditions

- The dependency direction decision is implicit, ownerless, or contradicted by the implementation.
- Evidence demonstrates only intent, compilation, or a happy path when stronger proof is practical.
- Residual risk is hidden, unbounded, or handed off without an owner and trigger.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../27-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
