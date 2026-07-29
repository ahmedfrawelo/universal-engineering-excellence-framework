# verification

Version: 1.0  
Pack: 02-installation  
Status: Stable  
Applies To: tasks where verification materially affects the outcome

## Purpose

This module establishes the enforceable **verification** contract for installation lifecycle, platform integration, and recovery. It exists to turn that concern into explicit decisions, safeguards, and completion evidence.

## Apply When

- The request names verification or changes behavior governed by it.
- Repository inspection finds an affected boundary, convention, artifact, or risk.
- A reviewer cannot prove the outcome without making the verification decision explicit.

## Required Decisions

1. State the observable outcome and owner for verification.
2. Make every install, update, and removal step idempotent or explicitly reversible.
3. Record assumptions, rejected alternatives, and the condition that would require revisiting the decision.

## Mandatory Safeguards

- Preserve user-owned configuration and report every path that is changed.
- Reuse the repository's existing owner, pattern, and automation before adding a parallel mechanism.
- Keep failure behavior explicit, bounded, diagnosable, and recoverable in proportion to risk.

## Required Evidence

- Direct evidence that the verification outcome works in the changed context.
- a clean-platform or fixture result plus post-operation status evidence.
- A focused regression check for the nearest behavior that could be broken.

## Failure Conditions

- The verification decision is implicit, ownerless, or contradicted by the implementation.
- Evidence demonstrates only intent, compilation, or a happy path when stronger proof is practical.
- Residual risk is hidden, unbounded, or handed off without an owner and trigger.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../27-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
