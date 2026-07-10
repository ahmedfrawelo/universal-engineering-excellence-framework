# Application Model Selector

Version: 1.1.0  
Status: Enforced  
Applies to: product UI, services, APIs, and data paths where relevant

## Purpose

Selects SaaS, internal employee, public free, or hybrid behavior from audience, data, tenancy, and entitlement evidence.

## Required Practice

- Record actors, organizations, trust boundaries, data owners, and revenue or entitlement rules.
- Do not infer trust from network location or UI route.
- For hybrid products, define boundaries between public, authenticated, employee, and administrative capabilities.

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
