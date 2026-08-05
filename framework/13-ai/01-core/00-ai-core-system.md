# Ai Core

Version: 1.0
Pack: 13-ai/01-core
Status: Stable
Applies To: tasks where ai core materially affects the outcome

## Purpose

This module establishes the enforceable **ai core** contract for safe AI feature boundaries, model contracts, and deterministic fallbacks. It exists to turn that concern into explicit decisions, safeguards, and completion evidence.

## Apply When

- The request names ai core or changes behavior governed by it.
- Repository inspection finds an affected boundary, convention, artifact, or risk.
- A reviewer cannot prove the outcome without making the ai core decision explicit.

## Required Decisions

1. State the observable outcome and owner for ai core.
2. Separate probabilistic output from deterministic policy and business invariants.
3. Record assumptions, rejected alternatives, and the condition that would require revisiting the decision.

## Mandatory Safeguards

- Treat model output as untrusted input and bound cost, latency, and data exposure.
- Reuse the repository's existing owner, pattern, and automation before adding a parallel mechanism.
- Keep failure behavior explicit, bounded, diagnosable, and recoverable in proportion to risk.

## Required Evidence

- Direct evidence that the ai core outcome works in the changed context.
- evaluation results, fallback tests, and policy enforcement evidence.
- A focused regression check for the nearest behavior that could be broken.

## Failure Conditions

- The ai core decision is implicit, ownerless, or contradicted by the implementation.
- Evidence demonstrates only intent, compilation, or a happy path when stronger proof is practical.
- Residual risk is hidden, unbounded, or handed off without an owner and trigger.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../12-delivery-quality/04-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
