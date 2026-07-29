# Frontend Engineering

Version: 1.1
Pack: 10-frontend  
Status: Stable  
Applies To: browser-side routes, components, state, assets, and delivery behavior

## Purpose

This module governs frontend ownership, rendering, state, accessibility, security, responsiveness, and delivery performance.

## Architecture Contract

- Organize files under the owning route, feature, component library, state or data layer, test folder, or asset pipeline.
- Split large frontend files before rendering, remote data, local interaction state, transformation, validation, styling, and tests become mixed responsibilities.
- Search components, tokens, layouts, services, clients, hooks, stores, validators, and registries before creating a local alternative.
- Keep server state distinct from view state; define cache, freshness, invalidation, optimistic update, and recovery behavior.

## Rendering and Delivery

- Prevent over-rendering by checking state ownership, selector scope, subscriptions, effect dependencies, memoization boundaries, expensive computation, virtualization, and route or component splitting.
- Animations must use transform and opacity by default, avoid layout thrashing, support reduced motion, and prevent animation state from re-rendering unrelated UI.
- Evaluate SSR, SSG, streaming, pre-rendering, or server components for public, content-heavy, SEO-sensitive, slow-first-paint, or data-heavy entry views.
- Do not force SSR into authenticated operational screens or unsupported architectures; record the evidence-based decision.

## Interaction and Safety

- Define loading, empty, error, disabled, submitted, offline, focus, and recovery states.
- Support keyboard, pointer, touch, zoom, text scaling, orientation, narrow width, and small height where applicable.
- Treat rendered content and URLs as untrusted, keep authorization server-side, and prevent duplicate submission.
- Preserve user context during refresh, reconnect, invalidation, and error recovery.

## Required Evidence

- Production build and focused component or integration tests.
- Rendered evidence across supported themes, breakpoints, interaction states, and input modes.
- Accessibility checks plus relevant performance measurements or budgets.
- A reuse decision and an explicit explanation for any new shared primitive.

## Failure Conditions

- Duplicate UI or state mechanisms are introduced without ownership evidence.
- Only the visual happy path is reviewed.
- Client enforcement is treated as authorization or sensitive data is unnecessarily exposed.
- Performance, accessibility, or responsive claims lack direct evidence.
