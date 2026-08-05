# Measurement and Benchmarking

Measurements must separate stages rather than reporting one total duration.

## Required Timing Buckets

Measure applicable cold and warm values for:

- route initialization, component initialization, time before request, duplicate-request delay
- DNS, TCP, TLS, proxy, upload, server wait, TTFB, download
- middleware, authentication, authorization, controller, service, cache lookup, cache deserialization
- SQL connection acquisition, count query, rows query, execution, blocking, waits, mapping
- serialization, compression, browser JSON parse, state update, change detection, DOM/grid render, time to interactive

## Required Scenarios

Compare:

- first request after restart and second request
- cache miss and cache hit
- first page, middle page, and deep page
- default sort and alternative sort
- no filters, realistic filters, broad search, exact search
- one user, normal concurrency, peak concurrency, and safe stress or soak when approved
- production-like data volume and production-like configuration

## Reliability Rules

Do not trust a single run. Call out distortion from local dev mode, debug builds, devtools overhead, browser extensions, warm plan cache, database buffer cache, Redis warm cache, JIT, smaller test data, different indexes, background jobs, antivirus, maintenance, and missing p95 or p99 evidence.
