# Technology Packs

Version: 1.0
Pack: 15-tech-stacks/01-technology-packs
Status: Stable
Applies To: tasks where technology packs materially affects the outcome

## Purpose

This module establishes the enforceable **technology packs** contract for conditional stack-specific guidance without weakening core rules. It exists to turn that concern into explicit decisions, safeguards, and completion evidence.

## Apply When

- The request names technology packs or changes behavior governed by it.
- Repository inspection finds an affected boundary, convention, artifact, or risk.
- A reviewer cannot prove the outcome without making the technology packs decision explicit.

## Required Decisions

1. State the observable outcome and owner for technology packs.
2. Load a technology pack only after detecting the stack and version.
3. Record assumptions, rejected alternatives, and the condition that would require revisiting the decision.

## Mandatory Safeguards

- Core architecture, security, and evidence requirements still take precedence.
- Reuse the repository's existing owner, pattern, and automation before adding a parallel mechanism.
- Keep failure behavior explicit, bounded, diagnosable, and recoverable in proportion to risk.

## Required Evidence

- Direct evidence that the technology packs outcome works in the changed context.
- detected stack evidence and the selected pack-specific checks.
- A focused regression check for the nearest behavior that could be broken.

## Failure Conditions

- The technology packs decision is implicit, ownerless, or contradicted by the implementation.
- Evidence demonstrates only intent, compilation, or a happy path when stronger proof is practical.
- Residual risk is hidden, unbounded, or handed off without an owner and trigger.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../12-delivery-quality/04-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
