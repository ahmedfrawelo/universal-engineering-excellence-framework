# performance philosophy

Version: 1.0  
Pack: 08-performance  
Status: Stable  
Applies To: tasks where performance philosophy materially affects the outcome

## Purpose

This module establishes the enforceable **performance philosophy** contract for measurable latency, throughput, resource, and responsiveness goals. It exists to turn that concern into explicit decisions, safeguards, and completion evidence.

## Apply When

- The request names performance philosophy or changes behavior governed by it.
- Repository inspection finds an affected boundary, convention, artifact, or risk.
- A reviewer cannot prove the outcome without making the performance philosophy decision explicit.

## Required Decisions

1. State the observable outcome and owner for performance philosophy.
2. Set a budget before optimizing and measure the actual constrained path.
3. Record assumptions, rejected alternatives, and the condition that would require revisiting the decision.

## Mandatory Safeguards

- Do not trade correctness, security, or accessibility for unmeasured speed.
- Reuse the repository's existing owner, pattern, and automation before adding a parallel mechanism.
- Keep failure behavior explicit, bounded, diagnosable, and recoverable in proportion to risk.

## Required Evidence

- Direct evidence that the performance philosophy outcome works in the changed context.
- repeatable baseline and post-change measurements against a stated budget.
- A focused regression check for the nearest behavior that could be broken.

## Failure Conditions

- The performance philosophy decision is implicit, ownerless, or contradicted by the implementation.
- Evidence demonstrates only intent, compilation, or a happy path when stronger proof is practical.
- Residual risk is hidden, unbounded, or handed off without an owner and trigger.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../27-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
