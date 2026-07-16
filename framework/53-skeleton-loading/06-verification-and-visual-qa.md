# Verification And Visual QA

Verify the skeleton and final state at supported themes, viewports, zoom levels, reduced-motion settings, and realistic loading durations. Check no layout jump, no overflow, no clipped text, no focus loss, no duplicate loader, and no stale structure during transition.

Exercise three timing paths: data resolves before reveal, data resolves while the skeleton is visible, and loading exceeds the timeout or enters recovery. Verify no one-frame flash, no artificial delay of ready content, and no rapid skeleton-content-skeleton oscillation. Where SSR, hydration, streaming, or route pre-rendering applies, compare the server markup, first client render, and settled content for deterministic structure and zero hydration warnings.

Record direct evidence: component tests for state transitions, accessibility checks, build/type checks, and screenshots or interaction traces when visual behavior is changed. A passing build alone is insufficient.
