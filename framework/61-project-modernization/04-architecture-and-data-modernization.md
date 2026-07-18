# Architecture And Data Modernization

- Preserve domain language and business invariants while improving boundaries.
- Move dependencies toward stable abstractions and remove cycles with measured ownership changes.
- Consolidate duplicate shared capabilities under one canonical owner and migrate consumers through public imports.
- Treat API, event, schema, cache, file-format, and stored-state changes as versioned migrations.
- Use expand/migrate/contract for live data and distributed consumers; test forward and rollback paths.
- Keep security, tenant, audit, authorization, and idempotency behavior explicit during boundary changes.
- Record an ADR when modernization changes public contracts, deployment topology, data ownership, trust boundaries, or team ownership.
