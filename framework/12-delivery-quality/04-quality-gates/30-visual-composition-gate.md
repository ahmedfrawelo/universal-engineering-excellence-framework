# Visual Composition and Anti-Regression Gate

Completion- and release-blocking for new or redesigned pages, forms, dashboards, landing views, and responsive layouts. When applicable, this gate must be `PASS` before `GoalStatus: COMPLETE`.

## Pass Conditions

- The first viewport has a deliberate composition: no unexplained dead space, accidental half-width content, clipped shell, or dominant empty region.
- Layout tracks respond to actual content density. Sparse forms do not leave unused columns; dense content does not become cramped or unreadable.
- Hierarchy is visible through scale, spacing, alignment, contrast, grouping, and action priority before decoration or animation is considered.
- The page has a clear primary task, readable line lengths, stable section rhythm, and intentional desktop/tablet/mobile compositions.
- Screenshots or live inspection cover initial, filled, validation-error, loading, empty, long-label, RTL, dark/light, reduced-motion, and narrow-width states where applicable.

## Fail Conditions

Fail on auto-grid layouts that create large blank cells, content stranded in a narrow column without intent, repeated cards with no hierarchy, oversized headings that push the task below the fold, invisible/low-contrast controls, screenshot-only approval, or a page that looks acceptable only at one viewport.

Passing build/tests do not override this gate.
