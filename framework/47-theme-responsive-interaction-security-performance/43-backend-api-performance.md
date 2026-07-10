# Backend and API Performance

Version: 1.1.0  
Status: Enforced  
Applies to: product UI, services, APIs, and data paths where relevant

## Purpose

Controls request latency, concurrency, allocation, serialization, dependencies, and resilience.

## Required Practice

- Set end-to-end and dependency time budgets with cancellation propagation.
- Batch independent I/O, eliminate N+1 calls, bound concurrency, and cache only with explicit invalidation.
- Load-test realistic percentiles and failure modes, not average happy paths.

## Delivery Contract

Before editing, record the existing project evidence and the intended extension point. During implementation, keep policy in shared tokens, components, services, middleware, or data access boundaries rather than page-specific patches. At review, demonstrate behavior at relevant themes, viewport sizes, input modes, trust boundaries, and realistic load. Exceptions require an owner, rationale, risk, expiry condition, and regression test.

## Verification Evidence

- [ ] The applicable existing system was inspected before implementation.
- [ ] Automated or repeatable checks cover the primary contract.
- [ ] A realistic manual or integration scenario covers behavior tools cannot prove.
- [ ] Residual risks and non-applicable checks have concrete reasons.

## Failure Conditions

- Implementation relies on page-specific values or behavior without justification.
- Accessibility, security, or performance is asserted without evidence.
- A supported theme, viewport, input method, or failure path is visibly broken.

## Related Modules

- `framework/46-design-system-consistency-reuse/README.md`
- `framework/27-quality-gates/19-theme-responsive-interaction-security-performance-gate.md`
- `framework/28-scorecards/15-theme-responsive-interaction-security-performance-scorecard.md`

## Completion Rule

This module passes only when implementation evidence demonstrates the required behavior. A build alone is not evidence of visual, interaction, security, or performance correctness.
