# Engineering Guardian

Version: 1.3.0  
Status: Enforced  
Applies to: every engineering task and release decision

## Purpose

Creates a permanent quality layer that prevents engineering degradation and requires every task to leave the project equal or better.

## Guardian Rules

- The Master Loader selects Guardian modules for every non-trivial engineering task.
- Zero-regression, security, performance, design, architecture, and final gates are integrated.
- Health evidence, baseline comparisons, and residual risks are recorded.

## Required Evidence

Before completion, compare the affected behavior with its baseline. Inspect the architecture, security boundary, performance path, design system, accessibility behavior, tests, documentation, and developer experience that the change touches. A regression must block completion and release claims until fixed or explicitly accepted by an accountable owner, with a recorded follow-up. Continue implementing the fix unless further work would risk irreversible user or data harm. Never hide a quality decrease behind a green build.

- [ ] A task treats green build as sufficient proof.
- [ ] Regression is known but left unfixed or unowned.
- [ ] Guardian guidance is detached from the existing UEEF gates.

## Failure Conditions

- A known regression is left unresolved without an explicit, time-bounded risk decision.
- A task increases duplication, complexity, technical debt, security exposure, accessibility debt, or performance cost silently.
- Review claims improvement without a before-and-after baseline or direct evidence.

## Completion Rule

This module passes only when the change leaves the affected project area equal or better across applicable engineering dimensions, with residual risk visible and owned.

## Related Packs

- framework/24-ai-review
- framework/27-quality-gates
- framework/28-scorecards
- framework/48-design-governance
- framework/47-theme-responsive-interaction-security-performance
