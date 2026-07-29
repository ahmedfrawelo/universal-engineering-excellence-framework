# dependency security

Version: 1.0  
Pack: 07-security  
Status: Stable  
Applies To: tasks where dependency security materially affects the outcome

## Purpose

This module establishes the enforceable **dependency security** contract for application security, abuse resistance, and data protection. It exists to turn that concern into explicit decisions, safeguards, and completion evidence.

## Apply When

- The request names dependency security or changes behavior governed by it.
- Repository inspection finds an affected boundary, convention, artifact, or risk.
- A reviewer cannot prove the outcome without making the dependency security decision explicit.

## Required Decisions

1. State the observable outcome and owner for dependency security.
2. Define the trust boundary, threat, prevention control, and safe failure mode.
3. Record assumptions, rejected alternatives, and the condition that would require revisiting the decision.

## Mandatory Safeguards

- Never expose secrets or sensitive data, and never rely on client-side enforcement alone.
- Reuse the repository's existing owner, pattern, and automation before adding a parallel mechanism.
- Keep failure behavior explicit, bounded, diagnosable, and recoverable in proportion to risk.

## Required Evidence

- Direct evidence that the dependency security outcome works in the changed context.
- negative-path security tests and a review of logs, errors, and data exposure.
- A focused regression check for the nearest behavior that could be broken.

## Failure Conditions

- The dependency security decision is implicit, ownerless, or contradicted by the implementation.
- Evidence demonstrates only intent, compilation, or a happy path when stronger proof is practical.
- Residual risk is hidden, unbounded, or handed off without an owner and trigger.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../27-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
