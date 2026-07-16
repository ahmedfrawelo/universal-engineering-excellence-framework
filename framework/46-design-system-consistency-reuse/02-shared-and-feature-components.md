# Shared and Feature Components

Version: 1.1.0  
Status: Enforced  
Applies to: product UI, services, APIs, and data paths where relevant

## Purpose

Defines when a component belongs globally and when it remains feature-owned.

## Required Practice

- Keep domain rules in feature components and generic interaction in shared components.
- Keep skeleton timing, cancellation, accessibility, motion, and base geometry in the shared loading contract. Feature components may compose domain structure but must not recreate the loading state machine or make the shared primitive depend on a feature store.
- Use explicit inputs, outputs, states, and accessibility contracts.
- Do not make global components depend on a feature store or feature API.
- Keep a shared primitive and its reusable recipes in one component-family owner. A recipe may specialize layout or domain-neutral composition, but it consumes the primitive and must not recreate its base behavior, tokens, motion, or accessibility contract.

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
