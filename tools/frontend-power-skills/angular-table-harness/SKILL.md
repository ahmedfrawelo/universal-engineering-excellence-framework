---
name: angular-table-harness
description: Create, extend, or review the Angular ComponentHarness for a shared custom data table. Use when table DOM changes or sorting, filtering, pagination, selection, actions, accessibility states, and RTL require a stable supported test API.
---

# Angular Table Harness

## Goal

Provide a stable user-facing test API independent of private DOM nesting and CSS classes.

## Inspect first

- Read the table public API and existing tests.
- Inspect installed Angular and Angular CDK versions and reuse harness conventions.
- Identify Angular Aria primitives and supplied harnesses.
- Map supported user tasks and states before adding methods.

## Rules

- Use a stable host selector and keep locators private.
- Return semantic values, not raw elements; prefer labels, roles, and public state over styling assertions.
- Expose only supported user actions and never expose a generic selector escape hatch.
- Keep methods stable across visual redesigns and treat breaking changes like component API changes.

## Minimum capabilities when supported

- Row count, visible columns, and cell text by row and column identity.
- Loading, empty, no-results, and error states.
- Sort, filter, selection, row/bulk actions, permissions, pagination, accessible names, and announced state.

## Tests

- Cover public inputs/outputs, client/server query contracts, permissions, loading, errors, keyboard behavior, RTL/LTR, long content, and nulls.
- Test semantic results and supported actions rather than CSS classes or private markup.

## Completion

Report the supported harness API, hidden implementation details, tests added, dependency impact, and consumer migration notes.
