# Data Grid Platform Gate

Release-blocking for table and data-grid work.

Pass only when the visual baseline is traced to the existing design system, query state is explicit, server-side capabilities are allowlisted, pagination/filter/sort/aggregate semantics are correct, performance budgets are measured, API/database/security contracts are implemented, and realtime/refresh behavior is defined where applicable. Advanced grids must also define persisted views, column state, selection scope, editing conflicts, export scope, accessibility/localization states, recovery behavior, schema evolution, capacity limits, caching/freshness, data-quality checks, and degraded-mode controls.

Fail on page-specific duplicate grids, client-only processing of large/private data, page totals presented as dataset totals, arbitrary query fields, unbounded page/export sizes, stale event overwrites, full reloads for targeted events, missing tenant authorization, unsafe persisted state, ambiguous select-all behavior, silent edit conflicts, unbounded synchronous exports, inaccessible state feedback, or UI claims without backend evidence.
