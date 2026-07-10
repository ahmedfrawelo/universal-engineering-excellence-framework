# Theme Responsive Interaction Security and Performance Quality Gate

Version: 1.1.0  
Status: Enforced  
Applies to: product UI, services, APIs, and data paths where relevant

## Purpose

Aggregates release-blocking checks for the complete pack.

## Required Practice

- Fail on theme drift, missing responsive states, inconsistent overlays, accessibility defects, security gaps, or unsupported performance claims.
- Require direct evidence for every applicable category.
- Record non-applicable checks with a concrete reason.

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

## Mandatory Failure Matrix

Fail when UI ignores the existing theme, bypasses semantic tokens, uses arbitrary colors or radii, introduces dashed or dotted UI lines, or has broken light, dark, or system behavior. Fail when responsive behavior is missing across supported widths, heights, orientation, zoom, or text scaling. Fail when overlays lack same-trigger close, outside dismissal, peer coordination, Escape, focus restoration, viewport collision, scroll, or semantic layering behavior.

Also fail when reduced motion is ignored, duplicate submission remains possible, security review or backend authorization is missing, tenant isolation is unverified, critical rendering or query waste remains, large lists are unbounded, or performance is claimed without repeatable measurement. Applicable UI work fails when UI UX Pro Max was available but not applied.

A failed item cannot be averaged away. The task remains incomplete until fixed or proven not applicable.
