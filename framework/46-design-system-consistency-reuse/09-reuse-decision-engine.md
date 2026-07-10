# Reuse Decision Engine

Version: 1.1.0  
Status: Enforced  
Applies to: product UI, services, APIs, and data paths where relevant

## Purpose

Chooses reuse, extension, composition, promotion, or intentional separation.

## Required Practice

- Reuse unchanged when semantics and states match.
- Extend through supported variants when the difference is visual or optional.
- Compose when behavior is shared but structure differs.
- Keep separate when domain meaning, lifecycle, security, or accessibility contracts conflict.

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
