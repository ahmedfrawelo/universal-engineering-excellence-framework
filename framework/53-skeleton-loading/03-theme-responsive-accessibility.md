# Theme Responsive Accessibility

Skeleton colors, contrast, radius, spacing, and motion come from governed design tokens and work in light, dark, and system themes. The layout must survive mobile, tablet, desktop, orientation, zoom, text scaling, and constrained height.

Mark decorative skeleton regions `aria-hidden="true"` and expose a concise live loading status only when it helps the user. Respect `prefers-reduced-motion`; animation is optional and must not be required to understand progress. Do not use color or shimmer as the only state signal.
