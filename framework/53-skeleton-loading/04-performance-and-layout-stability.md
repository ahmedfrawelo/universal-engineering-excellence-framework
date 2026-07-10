# Performance And Layout Stability

Reserve final dimensions before data arrives. Use stable CSS layout, aspect-ratio, min/max constraints, and content-length estimates to prevent cumulative layout shift. Prefer CSS-only, low-cost animation; avoid JavaScript timers, per-row subscriptions, and unbounded skeleton duplication.

Measure loading and transition behavior with realistic data, slow network, empty data, errors, and partial responses. Skeleton work must not increase bundle cost or render complexity without evidence.
