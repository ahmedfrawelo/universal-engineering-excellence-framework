---
name: company-data-table
description: Design, implement, review, test, or modify custom Angular data-table components. Use for columns, density, sorting, filtering, pagination, selection, row actions, states, sticky behavior, responsive adaptation, accessibility, Arabic, and RTL/LTR while preserving public APIs and business behavior.
---

# Company Data Table

## Inspect first

- Read the repository frontend playbook when present.
- Inspect the component public API, consumers, tests, styles, tokens, fixtures, and stories.
- Identify client/server ownership for sorting, filtering, pagination, and aggregation.
- Identify permission, selection, export, bulk-action, and row-action behavior.
- Capture the current route or story before editing when browser policy permits.

## Hard boundaries

- Do not install a third-party table UI library.
- Preserve public APIs and business behavior unless a documented migration is necessary.
- Use semantic design tokens and existing shared primitives; never hand-edit generated token files.
- Use logical CSS properties and verify RTL/LTR.
- Prefer native table semantics for read-oriented data; use ARIA grid only for genuine cell navigation.

## Visual and behavioral contract

- Prioritize identifiers and decision-driving values, align text to inline-start and numbers to inline-end, and keep actions at logical inline-end.
- Avoid decorative cell borders and never communicate status only through color.
- Cover loading, empty, no-results, recoverable error, long bilingual content, nulls, numeric edges, selection, permissions, many columns, and narrow viewports.
- Evaluate priority hiding, horizontal scroll, sticky identifiers, details drawers, and mobile list/card transformation deliberately.
- Preserve page-reset, selection persistence, permission, export, and query behavior during visual redesigns.
- Keep sticky regions from obscuring focused controls and format values by locale.

## Verification

- Reuse deterministic fixtures across unit, harness, Storybook, accessibility, and visual checks.
- Test relevant widths around 375, 768, 1024, and 1440 pixels plus the real transition width.
- Verify keyboard order, focus, accessible names/states, result announcements, 200% zoom, overflow, clipping, and sticky boundaries.
- Never update screenshot baselines before explaining each changed region.

## Completion report

Report behavior/API changes, tokens/components changed, states covered, commands and results, visual/accessibility evidence, and remaining risks.
