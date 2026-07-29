# Ai Intelligence

Version: 1.0  
Pack: 22-ai-intelligence  
Status: Stable  
Applies To: tasks where ai intelligence materially affects the outcome

## Purpose

This module establishes the enforceable **ai intelligence** contract for AI reasoning quality, evaluation, and decision support. It exists to turn that concern into explicit decisions, safeguards, and completion evidence.

## Apply When

- The request names ai intelligence or changes behavior governed by it.
- Repository inspection finds an affected boundary, convention, artifact, or risk.
- A reviewer cannot prove the outcome without making the ai intelligence decision explicit.

## Required Decisions

1. State the observable outcome and owner for ai intelligence.
2. Define a measurable task, baseline, evaluation set, and acceptable failure rate.
3. Record assumptions, rejected alternatives, and the condition that would require revisiting the decision.

## Mandatory Safeguards

- Do not infer intelligence quality from plausible examples alone.
- Reuse the repository's existing owner, pattern, and automation before adding a parallel mechanism.
- Keep failure behavior explicit, bounded, diagnosable, and recoverable in proportion to risk.

## Required Evidence

- Direct evidence that the ai intelligence outcome works in the changed context.
- repeatable evaluation results segmented by important failure modes.
- A focused regression check for the nearest behavior that could be broken.

## Failure Conditions

- The ai intelligence decision is implicit, ownerless, or contradicted by the implementation.
- Evidence demonstrates only intent, compilation, or a happy path when stronger proof is practical.
- Residual risk is hidden, unbounded, or handed off without an owner and trigger.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../27-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
