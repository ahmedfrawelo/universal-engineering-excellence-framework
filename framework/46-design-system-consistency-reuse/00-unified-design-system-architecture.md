# Unified Design System Architecture

Version: 1.1.0  
Status: Enforced  
Applies to: product UI, services, APIs, and data paths where relevant

## Purpose

Establishes one governed system for visual language, components, behavior, and product patterns.

## Required Practice

- Separate foundations, primitives, composites, feature components, layouts, and page templates.
- Give each layer a public API and prevent feature code from reaching into implementation internals.
- Version shared contracts and publish migration notes for breaking changes.
- Reusable UI must live in the appropriate shared design-system owner: token, primitive, composite, layout, template, pattern, or feature-extension layer.
- Before creating custom UI, search existing shared components, tokens, layouts, pattern libraries, registries, and examples. Reuse first, extend second, create new only with documented evidence.
- Feature-local custom UI is acceptable only when the behavior is genuinely single-use or intentionally isolated by product ownership.

## Delivery Contract

Before editing, record the existing project evidence and the intended extension point. During implementation, keep policy in shared tokens, components, services, middleware, or data access boundaries rather than page-specific patches. At review, demonstrate behavior at relevant themes, viewport sizes, input modes, trust boundaries, and realistic load. Exceptions require an owner, rationale, risk, expiry condition, and regression test.

## Verification Evidence

- [ ] Existing design-system evidence is recorded.
- [ ] At least one realistic consumer or scenario verifies the contract.
- [ ] Accessibility, theme, responsive, and interaction states are covered.
- [ ] Registry, tests, and migration notes are updated when applicable.

## Failure Conditions

- A suitable existing capability was ignored.
- A page-specific implementation duplicates shared behavior.
- A reusable component was implemented inside a feature instead of the shared design-system owner.
- A new custom component bypasses existing tokens, components, layouts, or pattern-library conventions.
- The contract lacks ownership or regression evidence.

## Related Modules

- `framework/47-theme-responsive-interaction-security-performance/README.md`
- `framework/27-quality-gates/19-theme-responsive-interaction-security-performance-gate.md`

## Completion Rule

This module passes only when implementation evidence demonstrates the required behavior. A build alone is not evidence of visual, interaction, security, or performance correctness.
