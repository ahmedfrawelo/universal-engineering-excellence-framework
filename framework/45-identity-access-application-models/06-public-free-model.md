# Public Free Application Model

Version: 1.1.0  
Status: Enforced  
Applies to: product UI, services, APIs, and data paths where relevant

## Purpose

Covers anonymous access, abuse resistance, privacy minimization, and progressive authentication.

## Required Practice

- Collect the minimum data required for the public capability.
- Rate-limit and abuse-protect expensive or sensitive public endpoints.
- Preserve accessible public workflows without using dark patterns to force sign-in.

## Delivery Contract

Before editing, record the existing project evidence and the intended extension point. During implementation, keep policy in shared tokens, components, services, middleware, or data access boundaries rather than page-specific patches. At review, demonstrate behavior at relevant themes, viewport sizes, input modes, trust boundaries, and realistic load. Exceptions require an owner, rationale, risk, expiry condition, and regression test.

## Verification Evidence

- [ ] Application model and trust boundaries are recorded.
- [ ] Allow and deny paths are tested server-side.
- [ ] Tenant, entitlement, session, and audit behavior is verified where applicable.
- [ ] Access states remain accessible, themed, and responsive.

## Failure Conditions

- Client visibility is treated as authorization.
- Tenant context comes from an untrusted request value.
- A privileged action lacks an audit or recovery path.

## Related Modules

- `framework/07-security/README.md`
- `framework/47-theme-responsive-interaction-security-performance/39-database-and-tenant-security-hardening.md`

## Completion Rule

This module passes only when implementation evidence demonstrates the required behavior. A build alone is not evidence of visual, interaction, security, or performance correctness.
