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

## Test Selection Ladder

Use the cheapest layer that can prove the requested behavior. Move up only when the lower layer cannot prove the requirement.

1. Static contract check: schema, config, links, script syntax, generated artifact shape.
2. Unit or script test: pure behavior, parser, validator, policy, helper, command wrapper.
3. Integration test: component plus owner, API plus service, script plus generated fixture, runtime plus source copy.
4. Browser or end-to-end proof: only when DOM, visual, interaction, authentication, or browser session behavior is part of the requirement.
5. Fresh review: required only for eligible T4 closure or explicit high-risk independent verification.

## Regression Coverage Requirements

Every non-trivial fix needs a nearest regression check:

- bug fix: a test or command that would fail on the old behavior;
- performance fix: baseline/post-change measurement plus correctness check;
- docs/workflow fix: link, command, or example validation against current files;
- runtime fix: source validation plus installed runtime status after sync;
- browser fix: allowed Chrome path evidence when browser behavior is in scope.

## Evidence Quality

Evidence is strong only when it proves the requested behavior itself. Build success, generic tests, or prose summaries are not enough unless they directly cover the requirement.

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
- A broad completion claim is made from a narrow test that does not cover the requested behavior.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../27-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
