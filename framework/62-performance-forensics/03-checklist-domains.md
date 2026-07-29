# Checklist Domains

The checklist is a minimum baseline. Add stack-specific techniques discovered during inspection.

## Mandatory Domains

Evaluate every applicable item in these domains:

- pagination, server-side data retrieval, stable sorting, totals, deep-page behavior, cancellation, and unsafe page sizes
- cache layers: browser, HTTP, CDN, proxy, output cache, memory cache, Redis, ORM tracking, query-result, permission, reference data, count, read model, invalidation, stampede, hot keys, TTLs, and cache contamination
- SQL Server: plans, Query Store, statistics IO/TIME, logical reads, waits, scans/seeks/lookups, joins, sorts, spills, memory grants, parallelism, cardinality, parameter sniffing, non-SARGable predicates, tempdb, wide rows, configuration, and API-to-database network latency
- indexes: missing, unused, duplicate, overlapping, covering, filtered, computed, full-text, columnstore, fragmentation, maintenance, write overhead, and whether the optimizer actually uses them
- schema and data modeling: normalization, denormalization, wide tables, types, keys, foreign-key indexes, soft delete, tenancy, audit/history, partitioning, read models, materialization, retention, and compression
- ORM/data access: tracking, projection, includes, N+1, split/single queries, premature materialization, client evaluation, compiled queries, raw SQL or Dapper suitability, cancellation, pooling, retries, transactions, duplicate queries
- backend/API: sync blocking, thread pool, middleware, auth, DI lifetimes, mapping, serialization, response envelopes, external calls, logging, feature flags, startup/JIT, GC, pooling, streaming, compression, HTTP version, connection reuse
- authentication, authorization, permissions, tenancy, encryption, masking, audit logging, and row-level or per-row checks
- payload and serialization: size, compressed size, unnecessary fields, nested entities, lookup repetition, DTOs, sparse fields, conditional requests, serialization/deserialization time
- frontend and table/grid: bundles, lazy loading, Angular mode, change detection, signals/RxJS, duplicate subscriptions, request cancellation, template functions, trackBy, DOM size, virtualization, grid refreshes, hidden DOM, layout thrashing, memory leaks, perceived performance
- network, DNS, TLS, redirects, CORS, oversized cookies/headers, CDN, WAF, proxy buffering, compression, regions, packet loss, and transport version
- infrastructure: regions, CPU, memory, disk, container/serverless limits, cold starts, autoscaling, service tiers, app pool recycling, Kestrel/IIS/proxy config, OS limits
- concurrency and scalability: locks, deadlocks, long transactions, pool exhaustion, thread starvation, queue buildup, cache stampede, retries, backpressure, rate limits, replicas, sharding
- advanced architecture: CQRS, read models, materialized or indexed views, search engines, queues, CDC, replicas, partitioning, API aggregation, streaming, delta sync, prefetching
- observability: logs, correlation IDs, traces, APM, Query Store, Extended Events, Redis metrics, browser profiles, Web Vitals, p50/p95/p99, RUM, synthetic, load/stress/soak tests

## Status Values

Use only:

- Working correctly
- Defective
- Missing and applicable
- Not applicable
- Unable to verify
