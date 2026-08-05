# Cloud

Version: 1.0
Pack: 15-tech-stacks/08-cloud
Status: Stable
Applies To: tasks where cloud materially affects the outcome

## Purpose

This module establishes the enforceable **cloud** contract for cloud reliability, least privilege, cost, portability, and recovery. It exists to turn that concern into explicit decisions, safeguards, and completion evidence.

## Apply When

- The request names cloud or changes behavior governed by it.
- Repository inspection finds an affected boundary, convention, artifact, or risk.
- A reviewer cannot prove the outcome without making the cloud decision explicit.

## Required Decisions

1. State the observable outcome and owner for cloud.
2. Treat infrastructure as versioned code and design for regional or service failure.
3. Record assumptions, rejected alternatives, and the condition that would require revisiting the decision.

## Mandatory Safeguards

- Do not grant wildcard access or create unbounded-cost resources.
- Reuse the repository's existing owner, pattern, and automation before adding a parallel mechanism.
- Keep failure behavior explicit, bounded, diagnosable, and recoverable in proportion to risk.

## Required Evidence

- Direct evidence that the cloud outcome works in the changed context.
- plan output, policy checks, cost bounds, resilience tests, and recovery evidence.
- A focused regression check for the nearest behavior that could be broken.

## Failure Conditions

- The cloud decision is implicit, ownerless, or contradicted by the implementation.
- Evidence demonstrates only intent, compilation, or a happy path when stronger proof is practical.
- Residual risk is hidden, unbounded, or handed off without an owner and trigger.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../12-delivery-quality/04-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
