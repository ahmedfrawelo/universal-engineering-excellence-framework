# Realtime Refresh Contract

## Scope And Freshness

- Mutable resources and query scopes:
- Freshness target and stale threshold:
- Push, invalidation, polling, or manual-refresh decision:
- Explicit no-page-reload proof:

## Event And Reconciliation

- Event ID, entity ID, operation, tenant/resource scope, version/sequence, schema version, correlation ID:
- Ordering, deduplication, replay, gap detection, and reconnect reconciliation:
- Targeted cache/state patch and preserved route/filter/selection/focus/scroll/edit context:
- Conflict handling and idempotency:

## Lifecycle And Failure

- Connect, heartbeat, token rotation, reconnect, background-tab, offline, resume, and disposal behavior:
- Retryable allowlist, `Retry-After`, retry owner, attempt/elapsed caps, backoff/jitter, and circuit breaker:
- Backpressure, queue bounds, burst coalescing, degraded mode, and kill switch:

## Security

- Connection and subscription authorization:
- Tenant and row isolation:
- WebSocket Origin and URL-credential controls:
- SSE CORS, credentials, caching, buffering, and heartbeat controls:
- Permission-revocation disconnect deadline:
- Payload schema, size, field allowlist, anti-replay, audit, and log redaction:

## Evidence

- Event-to-UI latency, stale age, render count, payload, queue, memory, reconnect, and dropped-event budgets:
- Revocation, tenant switch, expiry, replay, out-of-order, gap, slow-client, and reconnect-storm tests:
- Load and burst results:
- Runtime visual/state verification without page reload:
