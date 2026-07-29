# principal engineer mode

Version: 1.0  
Pack: 04-engineering  
Status: Stable  
Applies To: tasks where principal engineer mode materially affects the outcome

## Purpose

This module establishes the enforceable **principal engineer mode** contract for engineering judgment, tradeoffs, and sustainable delivery. It exists to turn that concern into explicit decisions, safeguards, and completion evidence.

## Apply When

- The request names principal engineer mode or changes behavior governed by it.
- Repository inspection finds an affected boundary, convention, artifact, or risk.
- A reviewer cannot prove the outcome without making the principal engineer mode decision explicit.

## Required Decisions

1. State the observable outcome and owner for principal engineer mode.
2. Choose the smallest coherent design that preserves future changeability.
3. Record assumptions, rejected alternatives, and the condition that would require revisiting the decision.

## Mandatory Safeguards

- Reject cleverness, abstraction, or reuse that lacks a demonstrated cost benefit.
- Reuse the repository's existing owner, pattern, and automation before adding a parallel mechanism.
- Keep failure behavior explicit, bounded, diagnosable, and recoverable in proportion to risk.

## Required Evidence

- Direct evidence that the principal engineer mode outcome works in the changed context.
- a concise rationale that connects the implementation to maintainability outcomes.
- A focused regression check for the nearest behavior that could be broken.

## Failure Conditions

- The principal engineer mode decision is implicit, ownerless, or contradicted by the implementation.
- Evidence demonstrates only intent, compilation, or a happy path when stronger proof is practical.
- Residual risk is hidden, unbounded, or handed off without an owner and trigger.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../27-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
