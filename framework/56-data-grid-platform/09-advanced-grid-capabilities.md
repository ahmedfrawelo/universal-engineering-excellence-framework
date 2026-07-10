# Advanced Data Grid Capabilities

Use this module when a grid is more than a read-only list. These capabilities must be explicit in the contract; they are not implied by rendering rows.

## View and State Persistence

- Treat column visibility, order, widths, pinning, density, grouping, filters, sort, page size, and active view as a versioned user preference.
- Keep shareable state in a stable URL only when it is safe, bounded, and useful for navigation. Do not put secrets, tenant identifiers, or unrestricted query payloads in URLs.
- Validate persisted state against the current schema and migrate or discard incompatible fields.
- Scope saved views by tenant, user, role, and resource. Enforce authorization on read and write.
- Provide reset-to-default and recoverable invalid-state behavior.

## Columns and Interaction

- Support column visibility, resize, reorder, and pinning only through declared capabilities.
- Keep a stable minimum width and readable fallback for narrow screens; do not make essential data inaccessible through horizontal overflow alone.
- Use stable column identifiers instead of display labels for state, exports, and API requests.
- Preserve keyboard equivalents for sorting, filtering, selection, resize, reorder, and row actions.

## Selection, Editing, and Bulk Actions

- Define whether selection is page-scoped, query-scoped, or explicit-ID scoped. Never infer "select all" from visible rows for a remote dataset.
- Bulk actions require a server-side authorization and validation path, bounded batch size, idempotency, progress, partial-failure reporting, and an audit record.
- Inline or bulk editing must use field allowlists, validation, optimistic-concurrency tokens, and a clear conflict resolution path.
- Do not silently overwrite a newer server version. Refresh or merge using entity versions.
- Keep undo semantics explicit: reversible client state is not a substitute for a server rollback contract.

## Export and Clipboard

- Export uses the same authorized query contract as the grid, but must declare whether it exports visible rows, selected rows, the current filtered dataset, or a bounded report.
- Large exports are asynchronous jobs with authorization re-checks, rate limits, expiry, cancellation, progress, audit logging, and safe download headers.
- Never build export SQL from client-provided field names or expressions. Use a server-owned projection registry.
- Clipboard and paste features sanitize cells, preserve type rules, cap payload size, and never bypass normal mutation validation.

## Accessibility, Localization, and State Feedback

- Use semantic table/grid roles only when the interaction model requires them; otherwise prefer native table semantics.
- Expose sort direction, selected state, loading state, result count, validation errors, and live updates to assistive technology without noisy announcements.
- Support keyboard navigation, visible focus, reduced motion, high contrast, zoom/text scaling, RTL, locale-aware dates/numbers, and translated empty/error/action states.
- Define distinct states for initial loading, background refresh, empty result, permission denied, stale data, offline, retrying, partial failure, and fatal failure.
- Preserve existing rows during background refresh and show freshness or pending-change status without causing layout shift.

## Observability and Recovery

- Track view-state migration failures, export jobs, selection mutations, conflict rates, stale data age, accessibility interaction failures, and retry outcomes.
- Use correlation/request IDs through grid, API, database, export worker, and realtime event paths.
- Test refresh, navigation, reconnect, permission changes, schema changes, and browser back/forward behavior with persisted state.

## Completion Rule

A grid is complete only when its state model, selection scope, edit conflict policy, export scope, accessibility behavior, localization behavior, and failure states are documented and tested in addition to its visual design and query performance.
