# Frontend Query And State Contract

Keep query state explicit and serializable: `page` or `cursor`, `pageSize`, filters, sort descriptors, visible columns, grouping, aggregate descriptors, search text, and request version. Debounce text search, cancel stale requests, deduplicate equivalent queries, preserve previous rows during background refresh, and make loading state specific to the affected region.

Separate server query state from local presentation state. Use stable row keys and track-by identity. Virtualize large lists, avoid per-cell subscriptions and repeated aggregate computation, and persist only approved view preferences.
