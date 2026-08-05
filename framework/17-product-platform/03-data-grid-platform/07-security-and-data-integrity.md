# Security And Data Integrity

Never trust client-visible columns, filters, sort fields, aggregate functions, tenant ids, or export scopes. Enforce capabilities server-side and return only authorized fields. Prevent cross-tenant cache leakage, timing leaks from unauthorized aggregates, injection through query descriptors, and export amplification.

Use optimistic concurrency or entity versions for edits. Define conflict behavior, idempotency keys for mutations, audit events, and safe retry semantics. Do not cache private grid data without an authorization-aware key and invalidation policy.
