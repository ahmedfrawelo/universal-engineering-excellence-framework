# Skeleton Loading Gate

Release-blocking for data-backed UI changes.

Pass only when the skeleton is structurally aligned with the final content, reused or intentionally governed, token-compliant, responsive, theme-safe, accessible, motion-safe, and verified against layout shift and state transitions. The implementation must cover the applicable `loading`, `content`, `empty`, `error`, `partial`, and refresh states. It must also use a shared reveal/minimum-duration policy, verify fast/normal/slow timing paths, evaluate SSR and hydration parity, and consume registered shared primitives or recipes through the established public API.

Fail on generic or stale skeletons, duplicate loading variants, indefinite loading, one-frame flashes, hiding a visible skeleton before the governed minimum duration, arbitrary feature timers, artificial delay of ready content, missing cancellation cleanup, replacing usable content with an initial skeleton during refresh, layout shift, hydration mismatch, unstable server/client structure, inaccessible announcements, shimmer-only meaning, page-specific hardcoded tokens, a duplicated local primitive when a registered shared capability exists, parallel shared skeleton folders or public imports with overlapping semantics, a recipe that reimplements the primitive instead of consuming it, or visual claims without direct evidence.
