# Pagination Filter Sort And Aggregation

Use server-side pagination, filtering, sorting, grouping, and aggregation when data volume or authorization scope makes client processing unsafe or expensive. Use a cursor for deep or frequently changing datasets; use page/offset where random page navigation and stable snapshots are required. Return total or has-more metadata explicitly.

Filter operators and sort fields must come from an allowlisted column schema. Aggregates must declare field, function, type, null behavior, precision, and scope. Distinguish page aggregates from dataset aggregates. Never calculate a dataset total from the current page and present it as a global total.
