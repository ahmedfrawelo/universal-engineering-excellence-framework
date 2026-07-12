# Final Guardian Gate

Version: 1.3.0  
Status: Enforced  
Applies to: every engineering task and release decision

## Purpose

Combines zero-regression, product quality, security, performance, architecture, and maintainability checks at completion.

## Guardian Rules

- Fail unresolved High or Critical security findings.
- Fail critical performance or accessibility regressions.
- Require direct evidence for all applicable guardian monitors.

## Required Evidence

Before completion, compare the affected behavior with its baseline. Inspect the architecture, security boundary, performance path, design system, accessibility behavior, tests, documentation, and developer experience that the change touches. A regression must block completion and release claims until fixed or explicitly accepted by an accountable owner, with a recorded follow-up. Continue implementing the fix unless further work would risk irreversible user or data harm. Never hide a quality decrease behind a green build.

- [ ] Affected baseline and scope are recorded.
- [ ] Relevant automated checks pass.
- [ ] Relevant manual, security, performance, UI, or operational evidence is recorded.
- [ ] Residual risk has an owner, threshold, and follow-up.

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
