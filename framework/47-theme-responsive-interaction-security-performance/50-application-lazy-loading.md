# Application Lazy Loading

Version: 1.2.0  
Status: Enforced  
Applies to: routes, features, components, assets, data, integrations, workers, and backend optional capabilities

## Required Practice

- Make an explicit eager, lazy, preload, prefetch, stream, or defer decision for every non-trivial load boundary.
- Keep first-use critical code, security bootstrap, theme initialization, shell structure, and essential accessibility behavior eager.
- Lazy-load non-critical routes, editors, charts, maps, rich previews, locales, large media, workers, optional integrations, and feature-only dependencies when measurement supports it.
- Group chunks by user workflow and ownership. Avoid one-request-per-component fragmentation, duplicate vendor chunks, serial request waterfalls, and hidden cross-feature imports that defeat splitting.
- Pair every lazy boundary with reserved layout, skeleton or progress state, timeout, retry, cancellation, error recovery, accessibility announcements, and reduced-motion behavior as applicable.
- Preload from navigation intent, idle time, viewport proximity, or known next steps only within network, memory, battery, and privacy budgets.
- On the backend, defer optional heavyweight providers and background capabilities without moving initialization into the first user request; use bounded warmup and health evidence.
- Measure initial and navigated bundle bytes, request count, cache hit rate, chunk reuse, time to usable content, layout shift, long tasks, memory, cold start, and lazy-load failures.

## Failure Conditions

- Everything is loaded eagerly without an explicit critical-path reason.
- Everything is split mechanically without measured benefit.
- Lazy boundaries cause waterfalls, blank regions, layout shift, inaccessible states, duplicated code, first-request cold starts, or unrecoverable navigation.

## Completion Rule

Lazy loading passes only when the boundary map, measured before/after evidence, failure states, caching, and real navigation behavior are verified.
