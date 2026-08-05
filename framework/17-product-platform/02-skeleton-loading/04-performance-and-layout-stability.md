# Performance And Layout Stability

Reserve final dimensions before data arrives. Use stable CSS layout, aspect-ratio, min/max constraints, and content-length estimates to prevent cumulative layout shift. Prefer CSS-only, low-cost animation; avoid JavaScript timers, per-row subscriptions, and unbounded skeleton duplication.

Use one shared timing policy rather than one timer per row or component. Reveal-delay and minimum-duration defaults must be configurable tokens with product evidence, not universal magic numbers. Measure skeleton mount cost, DOM count, animation paint cost, and the transition to content. Avoid random widths, unstable row counts, and layout values that differ between server and client.

Measure loading and transition behavior with realistic data, slow network, empty data, errors, and partial responses. Skeleton work must not increase bundle cost or render complexity without evidence.
