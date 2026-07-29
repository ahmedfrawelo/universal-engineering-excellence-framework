# Decision Engine

Version: 1.0  
Pack: 25-decision-engine  
Status: Stable  
Applies To: tasks where decision engine materially affects the outcome

## Purpose

This module establishes the enforceable **decision engine** contract for deterministic decision inputs, rules, conflicts, and explanations. It exists to turn that concern into explicit decisions, safeguards, and completion evidence.

## Apply When

- The request names decision engine or changes behavior governed by it.
- Repository inspection finds an affected boundary, convention, artifact, or risk.
- A reviewer cannot prove the outcome without making the decision engine decision explicit.

## Required Decisions

1. State the observable outcome and owner for decision engine.
2. Version rules and make precedence, defaults, and unknown inputs explicit.
3. Record assumptions, rejected alternatives, and the condition that would require revisiting the decision.

## Mandatory Safeguards

- Avoid hidden fallthrough behavior and non-reproducible decisions.
- Reuse the repository's existing owner, pattern, and automation before adding a parallel mechanism.
- Keep failure behavior explicit, bounded, diagnosable, and recoverable in proportion to risk.

## Required Evidence

- Direct evidence that the decision engine outcome works in the changed context.
- decision-table coverage including conflicts and boundary cases.
- A focused regression check for the nearest behavior that could be broken.

## Failure Conditions

- The decision engine decision is implicit, ownerless, or contradicted by the implementation.
- Evidence demonstrates only intent, compilation, or a happy path when stronger proof is practical.
- Residual risk is hidden, unbounded, or handed off without an owner and trigger.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../27-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
