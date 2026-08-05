# priority hierarchy

Version: 1.0  
Pack: 00-foundation  
Status: Stable  
Applies To: tasks where priority hierarchy materially affects the outcome

## Purpose

This module establishes the enforceable **priority hierarchy** contract for the framework's governing values and non-negotiable priorities. It exists to turn that concern into explicit decisions, safeguards, and completion evidence.

## Apply When

- The request names priority hierarchy or changes behavior governed by it.
- Repository inspection finds an affected boundary, convention, artifact, or risk.
- A reviewer cannot prove the outcome without making the priority hierarchy decision explicit.

## Required Decisions

1. State the observable outcome and owner for priority hierarchy.
2. Resolve competing concerns through the documented priority hierarchy and state the tradeoff.
3. Record assumptions, rejected alternatives, and the condition that would require revisiting the decision.

## Mandatory Safeguards

- Do not weaken correctness, user safety, or evidence to gain superficial speed.
- Reuse the repository's existing owner, pattern, and automation before adding a parallel mechanism.
- Keep failure behavior explicit, bounded, diagnosable, and recoverable in proportion to risk.

## Required Evidence

- Direct evidence that the priority hierarchy outcome works in the changed context.
- a traceable link from the decision to an explicit framework value.
- A focused regression check for the nearest behavior that could be broken.

## Failure Conditions

- The priority hierarchy decision is implicit, ownerless, or contradicted by the implementation.
- Evidence demonstrates only intent, compilation, or a happy path when stronger proof is practical.
- Residual risk is hidden, unbounded, or handed off without an owner and trigger.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../12-delivery-quality/04-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
