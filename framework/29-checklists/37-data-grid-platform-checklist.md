# Data Grid Platform Checklist

- [ ] Existing table/grid and theme were inspected and recorded as the visual baseline.
- [ ] Shared columns, filters, sort, pagination, overlays, virtualization, and aggregate patterns were reused or extended.
- [ ] Query state, cancellation, debounce, deduplication, stale response protection, and loading states are explicit.
- [ ] Pagination/cursor, filters, sorting, grouping, and page versus dataset aggregates are defined.
- [ ] Backend endpoint, validation, projection, indexes/query plan, authorization, tenant scope, and errors are defined.
- [ ] Performance budgets cover latency, payload, render time, memory, and interaction response.
- [ ] Realtime transport, event envelope, reconnect, ordering, deduplication, and refresh reconciliation are defined where needed.
- [ ] Security, concurrency, idempotency, audit, export limits, and cache isolation are tested.
- [ ] Accessibility, RTL, responsive overflow, keyboard behavior, visual regression, and E2E evidence pass.
- [ ] Saved views and URL state are versioned, scoped, bounded, validated, and resettable.
- [ ] Column visibility/order/width/pinning use stable IDs and remain usable on narrow screens.
- [ ] Selection scope, select-all behavior, bulk authorization, idempotency, progress, partial failures, and audit are defined.
- [ ] Editing uses field allowlists, entity versions, conflict handling, and explicit undo/rollback semantics.
- [ ] Export scope, async-job limits, expiry, cancellation, download security, and projection allowlists are defined.
- [ ] Empty, stale, offline, retrying, permission, partial-failure, and background-refresh states are accessible and localized.
