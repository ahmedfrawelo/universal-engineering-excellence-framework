# Frontend Rendering Performance

Version: 1.1.0  
Status: Enforced  
Applies to: product UI, services, APIs, and data paths where relevant

## Purpose

Minimizes rendering, JavaScript, layout, media, and main-thread cost.

## Required Practice

- Measure component commits and stabilize state ownership before adding memoization.
- Virtualize large collections, reserve async layout space, and split code by route or feature.
- Track Core Web Vitals and input responsiveness on representative devices.
- Prevent over-rendering by reviewing component boundaries, selectors, subscriptions, effect dependencies, memoization, derived state, computed values, table/list virtualization, and route-level code splitting.
- Keep animation work on compositor-friendly properties such as transform and opacity; avoid layout-triggering animation, animation-driven server calls, and state loops that repaint unrelated regions.
- Evaluate SSR, SSG, streaming, route-level pre-rendering, or server components for public, content-heavy, SEO-sensitive, slow-to-hydrate, or first-view data-heavy routes when the stack supports them.
- Keep authenticated operational screens client-rendered when that matches the product architecture, but document why SSR is not useful for those routes.
- Build and measure a route/feature/component/asset lazy-loading map. Preserve the critical path, avoid request waterfalls and duplicate chunks, and verify real navigation plus failure recovery.
- Reconcile remote updates at the smallest state boundary without page reload, broad component-tree reset, lost focus, lost scroll, or discarded unsaved work.

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
