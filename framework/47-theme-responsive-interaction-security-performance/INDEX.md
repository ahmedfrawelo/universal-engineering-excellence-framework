# Pack 47 Index

Version: 1.1.0  
Status: Enforced  
Applies to: product UI, services, APIs, and data paths where relevant

## Purpose

Routes tasks to theme modules 01-09, responsive modules 10-20, interaction modules 21-35, security modules 36-40, performance modules 41-46, review modules 47-49, application lazy loading module 50, and global live-refresh module 51.

## Required Practice

- Theme work begins with existing-theme compatibility and token architecture.
- Responsive and overlay work includes accessibility and input-mode contracts.
- Security and performance selections follow the affected trust and execution paths.
- Mutable remote state selects module 51; non-trivial load boundaries select module 50.

## Delivery Contract

Before editing, record the existing project evidence and the intended extension point. During implementation, keep policy in shared tokens, components, services, middleware, or data access boundaries rather than page-specific patches. At review, demonstrate behavior at relevant themes, viewport sizes, input modes, trust boundaries, and realistic load. Exceptions require an owner, rationale, risk, expiry condition, and regression test.

## Verification Evidence

- [ ] Every selected concern maps to an indexed module.
- [ ] The final gate and scorecard are included.

## Failure Conditions

- A task loads the entire pack without need.
- A cross-cutting risk has no selected owner module.

## Related Modules

- `framework/01-core/01-master-loader.md`
- `framework/MASTER_INDEX.md`

## Completion Rule

This module passes only when implementation evidence demonstrates the required behavior. A build alone is not evidence of visual, interaction, security, or performance correctness.
