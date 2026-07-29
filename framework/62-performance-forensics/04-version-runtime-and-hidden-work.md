# Version Runtime and Hidden Work

Performance audits must include version-specific and hidden-work checks.

## Version-Specific Checks

Inspect exact versions and compatibility settings for:

- .NET, Angular, Entity Framework, SQL Server, Redis, data-grid library, drivers, serializers, HTTP clients, operating system, web server, reverse proxy, CDN, authentication provider, and hosting platform
- unsupported or end-of-life versions
- known version-specific regressions or disabled performance features
- debug builds, development mode, stale deployments, mixed frontend/backend versions, environment overrides, dependency conflicts, and package duplication

## Hidden Duplicate Work

Search for repeated or hidden work caused by:

- route initialization, resolvers, guards, component initialization, child components, interceptors, retries, polling, automatic refresh, grid state restoration, permission loading, translation loading, and user-data loading
- uncancelled stale requests
- hidden tabs or inactive pages loading data
- modals, dropdowns, lookups, tooltips, or row actions loading before interaction
- table or grid destruction and recreation

## Query-Shape Alternatives

Benchmark alternatives only when relevant and safe:

- rewritten LINQ, manual projection, raw parameterized SQL, stored procedure, Dapper, temporary table, table-valued parameter, CTE, derived table, APPLY, EXISTS, UNION ALL, split query, single query, batch query, precomputed query, indexed view, read model, and background aggregation

Do not recommend an alternative based on theory alone.
