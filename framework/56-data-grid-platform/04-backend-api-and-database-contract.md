# Backend API And Database Contract

Define a versioned endpoint contract with validated query parameters, stable response envelopes, page/cursor metadata, column capabilities, aggregate results, correlation id, and structured errors. Enforce authorization and tenant scope before filtering, sorting, aggregation, export, or caching.

Translate allowlisted query descriptors into parameterized queries. Index common filters and sort orders, inspect query plans, cap page size and filter complexity, and apply timeouts/cancellation. Avoid N+1 queries, unbounded exports, arbitrary field names, and client-controlled SQL fragments. API design must be created alongside the grid, not after the UI.
