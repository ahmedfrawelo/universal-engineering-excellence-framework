# runtime contract

Version: 1.0  
Pack: 01-core  
Status: Stable  
Applies To: tasks where runtime contract materially affects the outcome

## Purpose

This module establishes the enforceable **runtime contract** contract for UEEF loading, routing, activation, and completion behavior. It exists to turn that concern into explicit decisions, safeguards, and completion evidence.

## Apply When

- The request names runtime contract or changes behavior governed by it.
- Repository inspection finds an affected boundary, convention, artifact, or risk.
- A reviewer cannot prove the outcome without making the runtime contract decision explicit.

## Required Decisions

1. State the observable outcome and owner for runtime contract.
2. Keep runtime claims machine-verifiable and consistent across supported platforms.
3. Record assumptions, rejected alternatives, and the condition that would require revisiting the decision.

## Mandatory Safeguards

- Do not claim activation, capability, or completion without the corresponding proof.
- Reuse the repository's existing owner, pattern, and automation before adding a parallel mechanism.
- Keep failure behavior explicit, bounded, diagnosable, and recoverable in proportion to risk.

## Required Evidence

- Direct evidence that the runtime contract outcome works in the changed context.
- status, route, and completion output that matches the executable contract.
- A focused regression check for the nearest behavior that could be broken.

## Failure Conditions

- The runtime contract decision is implicit, ownerless, or contradicted by the implementation.
- Evidence demonstrates only intent, compilation, or a happy path when stronger proof is practical.
- Residual risk is hidden, unbounded, or handed off without an owner and trigger.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../27-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
