# Skeleton Loading Checklist

- [ ] Existing loading primitives, page templates, components, and patterns were searched.
- [ ] Skeleton structure matches the final content regions and responsive layout.
- [ ] Loading, content, empty, error, partial, and refresh behavior are defined where applicable.
- [ ] Final dimensions are reserved and layout shift is checked.
- [ ] Light, dark, system, reduced-motion, zoom, text scaling, and constrained-height behavior are covered.
- [ ] Decorative regions are hidden from assistive technology and loading status is concise.
- [ ] No duplicate or stale skeleton exists for the same region.
- [ ] Shared reveal delay, minimum visible duration, timeout, cancellation, and stale-request behavior are defined.
- [ ] Fast, normal, slow, cancelled, retried, and superseded timing paths avoid flashes and oscillation.
- [ ] SSR, hydration, pre-rendering, and streaming applicability is recorded; applicable markup is deterministic and warning-free.
- [ ] Shared primitives or recipes are imported from the design-system public API and registered with ownership and tests.
- [ ] No page-local primitive duplicates a registered shared capability.
- [ ] Tests, build/type checks, and visual or interaction evidence are recorded.
