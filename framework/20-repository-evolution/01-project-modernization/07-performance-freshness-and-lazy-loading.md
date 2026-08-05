# Performance, Freshness, And Lazy Loading During Modernization

Every modernization plan must evaluate:

- route, feature, component, asset, locale, editor, chart, worker, integration, and optional-service lazy boundaries;
- critical-path eager loading, preloading, prefetching, request waterfalls, chunk duplication, cacheability, cold starts, and failure states;
- frontend render count, long tasks, memory, bundle/chunk size, network requests, layout stability, and input responsiveness;
- backend query count, rows scanned, serialization, payload size, allocations, concurrency, cancellation, cache invalidation, rate limits, and burst behavior;
- realtime event scope, ordering, deduplication, reconnect, backpressure, targeted reconciliation, stale age, and no-page-reload proof.

Do not lazy-load tiny critical dependencies, split code without measured benefit, or move server work into a first-request cold path. Do not use full page reload as a normal synchronization mechanism.
