# tool detection

Version: 1.0  
Pack: 03-runtime  
Status: Stable  
Applies To: tasks where tool detection materially affects the outcome

## Purpose

This module establishes the enforceable **tool detection** contract for the request-to-delivery execution lifecycle. It exists to turn that concern into explicit decisions, safeguards, and completion evidence.

## Apply When

- The request names tool detection or changes behavior governed by it.
- Repository inspection finds an affected boundary, convention, artifact, or risk.
- A reviewer cannot prove the outcome without making the tool detection decision explicit.

## Required Decisions

1. State the observable outcome and owner for tool detection.
2. Derive routing and verification from inspected task evidence rather than defaults.
3. Record assumptions, rejected alternatives, and the condition that would require revisiting the decision.

## Mandatory Safeguards

- Do not edit before scope, constraints, and required evidence are known.
- Reuse the repository's existing owner, pattern, and automation before adding a parallel mechanism.
- Keep failure behavior explicit, bounded, diagnosable, and recoverable in proportion to risk.

## Required Evidence

- Direct evidence that the tool detection outcome works in the changed context.
- a recorded lifecycle trace from classification through final verification.
- A focused regression check for the nearest behavior that could be broken.

## Failure Conditions

- The tool detection decision is implicit, ownerless, or contradicted by the implementation.
- Evidence demonstrates only intent, compilation, or a happy path when stronger proof is practical.
- Residual risk is hidden, unbounded, or handed off without an owner and trigger.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../27-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
