# Ai Memory

Version: 1.0  
Pack: 23-ai-memory  
Status: Stable  
Applies To: tasks where ai memory materially affects the outcome

## Purpose

This module establishes the enforceable **ai memory** contract for memory consent, relevance, isolation, retention, and deletion. It exists to turn that concern into explicit decisions, safeguards, and completion evidence.

## Apply When

- The request names ai memory or changes behavior governed by it.
- Repository inspection finds an affected boundary, convention, artifact, or risk.
- A reviewer cannot prove the outcome without making the ai memory decision explicit.

## Required Decisions

1. State the observable outcome and owner for ai memory.
2. Store only scoped information with provenance and an explicit retention policy.
3. Record assumptions, rejected alternatives, and the condition that would require revisiting the decision.

## Mandatory Safeguards

- Prevent cross-user leakage and support correction and deletion.
- Reuse the repository's existing owner, pattern, and automation before adding a parallel mechanism.
- Keep failure behavior explicit, bounded, diagnosable, and recoverable in proportion to risk.

## Required Evidence

- Direct evidence that the ai memory outcome works in the changed context.
- isolation, retrieval-quality, expiry, and deletion tests.
- A focused regression check for the nearest behavior that could be broken.

## Failure Conditions

- The ai memory decision is implicit, ownerless, or contradicted by the implementation.
- Evidence demonstrates only intent, compilation, or a happy path when stronger proof is practical.
- Residual risk is hidden, unbounded, or handed off without an owner and trigger.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../27-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
