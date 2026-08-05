# Production Data Delivery and Cost Controls

Use this module when a data view must remain reliable, affordable, and evolvable as traffic and data volume grow.

## Contract and Schema Evolution

- Version API envelopes and event schemas. Add fields compatibly before removing or renaming them.
- Define nullability, timezone, currency, precision, locale, enum evolution, and row identity explicitly.
- Reject unknown or ambiguous query capabilities at the boundary; do not let a client silently fall back to a slower or broader query.
- Publish deprecation windows, consumer telemetry, migration steps, and rollback behavior.

## Backpressure and Capacity

- Bound page size, filter complexity, concurrent requests, export jobs, event fan-out, and server-side work time.
- Use rate limits, concurrency limits, cancellation, queue backpressure, and retry budgets. Retries require jitter and must not amplify an outage.
- Prefer read models, materialized views, pre-aggregations, read replicas, or search indexes when measured query plans justify them.
- Define behavior when capacity is exhausted: a useful retry response, stale cache, degraded aggregate, or explicit unavailable state.

## Caching and Freshness

- Define cache keys from authorized tenant/user scope and the complete normalized query contract.
- Choose TTL, invalidation, stale-while-revalidate, and negative-cache rules deliberately. Never cache authorization failures as shared data.
- Reconcile cache invalidation with realtime events and version markers; do not assume delivery order across transports.
- Show freshness or stale status to users when the business decision depends on recency.

## Data Quality and Operations

- Validate totals, duplicate row IDs, missing pages, impossible aggregates, clock skew, and event gaps in monitoring and tests.
- Add reconciliation jobs or checksums for critical projections and materialized data.
- Emit metrics for rows scanned/returned, query cost, queue depth, cache hit ratio, stale age, throttling, and failed retries.
- Define retention, deletion, export privacy, and audit requirements for grid data and generated files.

## Cost and Failure Review

- Estimate worst-case database, network, worker, storage, and browser costs before enabling a capability globally.
- Load-test realistic distributions, skewed filters, concurrent users, reconnect storms, and large exports.
- Document a degraded mode and a kill switch for expensive filters, aggregates, exports, or realtime subscriptions.

## Completion Rule

Production readiness requires a compatibility plan, capacity limits, cache/freshness policy, data-quality checks, cost evidence, and a tested degraded mode in addition to functional correctness.
