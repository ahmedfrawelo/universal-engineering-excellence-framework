# testing and qa

Version: 1.0  
Pack: 17-testing  
Status: Stable  
Applies To: tasks where testing and qa materially affects the outcome

## Purpose

This module establishes the enforceable **testing and qa** contract for risk-based test strategy and trustworthy quality evidence. It exists to turn that concern into explicit decisions, safeguards, and completion evidence.

## Apply When

- The request names testing and qa or changes behavior governed by it.
- Repository inspection finds an affected boundary, convention, artifact, or risk.
- A reviewer cannot prove the outcome without making the testing and qa decision explicit.

## Required Decisions

1. State the observable outcome and owner for testing and qa.
2. Test observable behavior at the cheapest layer that can prove it.
3. Record assumptions, rejected alternatives, and the condition that would require revisiting the decision.

## Mandatory Safeguards

- Avoid brittle implementation-coupled tests and unverified happy-path-only claims.
- Reuse the repository's existing owner, pattern, and automation before adding a parallel mechanism.
- Keep failure behavior explicit, bounded, diagnosable, and recoverable in proportion to risk.

## Required Evidence

- Direct evidence that the testing and qa outcome works in the changed context.
- focused regression coverage plus the relevant integration or end-to-end proof.
- A focused regression check for the nearest behavior that could be broken.

## Failure Conditions

- The testing and qa decision is implicit, ownerless, or contradicted by the implementation.
- Evidence demonstrates only intent, compilation, or a happy path when stronger proof is practical.
- Residual risk is hidden, unbounded, or handed off without an owner and trigger.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../27-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
