# Form Table Modal and Notification Systems

Version: 1.1.0  
Status: Enforced  
Applies to: product UI, services, APIs, and data paths where relevant

## Purpose

Unifies high-frequency product systems and their states.

## Required Practice

- Centralize field labels, errors, validation timing, submission state, and focus-on-error behavior.
- Provide shared table wrappers for density, sorting, filtering, selection, pagination, and responsive strategy.
- Use one dialog and overlay foundation with typed dismissal reasons and focus restoration.
- Use accessible notification severity, duration, deduplication, and recovery actions.

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
