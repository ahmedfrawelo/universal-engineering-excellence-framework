# Data Grid Operational Runbook

Use this runbook when a grid or its data pipeline degrades in production.

## Slow Queries or Rendering

1. Capture request ID, normalized query, tenant scope, page/cursor, rows scanned/returned, database duration, payload size, and client render timing.
2. Check query-plan regression, missing indexes, filter selectivity, cache hit rate, browser memory, and long tasks before changing code.
3. Apply the smallest reversible mitigation: reduce limits, disable an expensive capability, serve a bounded stale result, or route to a read model.
4. Record the root cause and add a regression budget/test before restoring the capability.

## Stale or Incorrect Data

- Compare entity/version markers, event sequence, cache age, projection lag, and database truth.
- Stop stale event application when ordering or tenant scope cannot be proven.
- Invalidate or rebuild affected projections, then reconcile counts, IDs, and aggregates.
- Tell users whether the view is stale, partially refreshed, or authoritative.

## Realtime or Refresh Failure

- Verify authentication, subscription scope, heartbeat, reconnect backoff, event sequence, and server health.
- Fall back to bounded polling or manual refresh with visible freshness status; never spin an unbounded retry loop.
- Reconcile with a versioned query after reconnect and deduplicate events by event ID.

## Export or Bulk-Action Incident

- Pause or rate-limit the job class, preserve audit records, and prevent duplicate mutations with idempotency keys.
- Re-check authorization and projection scope before resuming.
- Report partial completion explicitly and provide a safe retry or compensation path.

## Exit Criteria

Close the incident only after metrics recover, data reconciliation passes, the mitigation is removed or documented, and a permanent prevention test, alert, or budget is linked to the incident.
