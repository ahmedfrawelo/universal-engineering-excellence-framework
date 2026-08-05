# Ux

Version: 1.0
Pack: 10-frontend/04-ux
Status: Stable
Applies To: tasks where ux materially affects the outcome

## Purpose

This module establishes the enforceable **ux** contract for user goals, task flows, feedback, and recovery. It exists to turn that concern into explicit decisions, safeguards, and completion evidence.

## Apply When

- The request names ux or changes behavior governed by it.
- Repository inspection finds an affected boundary, convention, artifact, or risk.
- A reviewer cannot prove the outcome without making the ux decision explicit.

## Required Decisions

1. State the observable outcome and owner for ux.
2. Minimize user effort while keeping consequences and system state understandable.
3. Record assumptions, rejected alternatives, and the condition that would require revisiting the decision.

## Mandatory Safeguards

- Do not create dead ends, ambiguous actions, or irreversible actions without confirmation.
- Reuse the repository's existing owner, pattern, and automation before adding a parallel mechanism.
- Keep failure behavior explicit, bounded, diagnosable, and recoverable in proportion to risk.

## Required Evidence

- Direct evidence that the ux outcome works in the changed context.
- task-flow evidence including error recovery and edge states.
- A focused regression check for the nearest behavior that could be broken.

## Failure Conditions

- The ux decision is implicit, ownerless, or contradicted by the implementation.
- Evidence demonstrates only intent, compilation, or a happy path when stronger proof is practical.
- Residual risk is hidden, unbounded, or handed off without an owner and trigger.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../12-delivery-quality/04-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
