# Performance Budgets and Measurement

Version: 1.1.0  
Status: Enforced  
Applies to: product UI, services, APIs, and data paths where relevant

## Purpose

Defines measurable release thresholds and repeatable collection methods.

## Required Practice

- Set p50, p95, and p99 latency, throughput, error, memory, CPU, query, bundle, and web-vital budgets as applicable.
- Record environment, dataset, device, network, warmup, sample size, and variance.
- Fail regressions beyond tolerance or require a documented, approved budget change.

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
