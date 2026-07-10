# Design System Consistency and Reuse

Version: 1.1.0  
Status: Enforced  
Applies to: product UI, services, APIs, and data paths where relevant

## Purpose

Defines the ownership model that prevents duplicate UI, behavior, validation, and integration code.

## Required Practice

- Treat the component registry and pattern library as the first search location before creating UI.
- Keep primitives, shared composites, feature components, layouts, and page templates in explicit ownership layers.
- Promote a pattern only after two proven consumers or a clear cross-product contract.

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
- The contract lacks ownership or regression evidence.

## Related Modules

- `framework/47-theme-responsive-interaction-security-performance/README.md`
- `framework/27-quality-gates/19-theme-responsive-interaction-security-performance-gate.md`

## Completion Rule

This module passes only when implementation evidence demonstrates the required behavior. A build alone is not evidence of visual, interaction, security, or performance correctness.
