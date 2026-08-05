# Performance And Scale

Set budgets for first meaningful rows, query latency, payload size, render time, memory, and interaction latency. Prefer projection over full entities, compressed responses, cache keys that include tenant/user/query/version, and stale-while-revalidate only where authorization and freshness permit.

Use virtual scroll only with measured row geometry and accessible keyboard behavior. Batch requests, cancel obsolete work, avoid duplicate refreshes, and keep aggregates on the server for large datasets. Test realistic row counts, slow networks, high-cardinality filters, deep pagination, and concurrent updates.
