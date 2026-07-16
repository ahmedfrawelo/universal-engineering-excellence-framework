# Shared Frontend Services Validation and API Clients

Version: 1.1.0  
Status: Enforced  
Applies to: product UI, services, APIs, and data paths where relevant

## Purpose

Prevents duplicate transport, validation, and cross-cutting frontend behavior.

## Required Practice

- Use one configured API client per backend boundary with authentication, correlation, cancellation, and error normalization.
- Share validation schemas where semantics match; keep server validation authoritative.
- Centralize overlay coordination, notifications, telemetry, preferences, and feature flags behind narrow interfaces.
- Place repeated hooks, stores, formatters, validators, mappers, API clients, data loaders, permission helpers, error handling, and cross-cutting UI services in shared owners.
- Feature code should import shared services through their public API. Do not duplicate transport, validation, mapping, notification, telemetry, or feature-flag logic inside each feature.
- When extending shared behavior, keep the public API narrow and add tests that cover at least one real consumer.
- Shared skeleton services expose one public timing and state API for delayed reveal, minimum visible duration, cancellation, stale-request suppression, retry, and content-preserving refresh. Keep this API independent of feature data access, register its owner, and verify it through real consumers.

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
- A repeated service, validator, client, mapper, store, hook, or utility is implemented feature-locally instead of in the shared owner.
- The contract lacks ownership or regression evidence.

## Related Modules

- `framework/47-theme-responsive-interaction-security-performance/README.md`
- `framework/27-quality-gates/19-theme-responsive-interaction-security-performance-gate.md`

## Completion Rule

This module passes only when implementation evidence demonstrates the required behavior. A build alone is not evidence of visual, interaction, security, or performance correctness.
