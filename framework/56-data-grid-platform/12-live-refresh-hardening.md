# Live Refresh Hardening Contract

Live refresh means the visible data changes without a browser/page reload. A refresh request may revalidate or reconcile data, but it must not reset the route, shell, scroll position, filters, selection, or unsaved edits.

## Frontend

- Subscribe once per active query/scope and dispose on route, tenant, permission, and component changes.
- Apply an event only when tenant/resource/query scope, entity identity, and version are valid. Drop duplicates and older versions.
- Patch affected rows or invalidate the smallest affected query. Preserve filters, sort, pagination/cursor, selection, focus, edits, and scroll.
- Use a quiet freshness indicator and accessible live status; never show a blocking spinner for a background update.
- Batch bursts, schedule non-urgent work, cancel obsolete refreshes, and avoid render storms or full component-tree reloads.
- Reconcile after reconnect or detected event gaps with a versioned query. Fall back to bounded polling without infinite retry.

## Backend and Transport

- Authenticate the connection and authorize every subscription against tenant, user, role, resource, and row scope.
- Use an event envelope containing event ID, entity ID, operation, scope, version/sequence, occurred-at, correlation ID, and schema version.
- Enforce bounded fan-out, connection limits, heartbeat, backpressure, rate limits, reconnect jitter, and event retention/gap recovery.
- Do not trust client-provided tenant, row, field, filter, or subscription scope. Re-check authorization on reconnect and sensitive mutations.
- Publish events only after the source-of-truth transaction commits, or label provisional events explicitly.

## Security and Integrity

- Prevent cross-tenant leakage through channel names, cache keys, event routing, logs, and error messages.
- Treat event payloads as untrusted input: validate schema, size, content, and allowed fields; never execute client-provided expressions.
- Protect mutation commands with idempotency keys, entity versions, anti-replay rules, audit records, and conflict handling.
- Test revoked permissions, tenant switches, token expiry, replayed events, out-of-order events, event gaps, and reconnect storms.

## Performance and Evidence

- Set budgets for event-to-UI latency, patch duration, dropped events, queue depth, reconnect time, payload size, memory, long tasks, and render count.
- Load-test bursts, many subscribers, slow clients, background tabs, large visible datasets, and simultaneous edits.
- Prove with logs and tests that no page reload occurs and that targeted updates preserve user context.

## Release Rule

No live-refresh feature passes without frontend reconciliation evidence, backend authorization evidence, transport lifecycle evidence, performance/load evidence, and security tests. Full page reload is a failure except for an explicitly documented unrecoverable bootstrap failure.
