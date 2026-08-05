# Fullstack Project Example

This example shows the minimum UEEF workflow for a change spanning frontend, backend, API contracts, persistence, realtime, or deployment behavior.

## Scenario

User request:

```text
Make the dashboard search faster and keep filters, pagination, and permissions correct.
```

## Route

- Intent: fullstack behavior and performance.
- Tier: T3 by default because frontend, API, backend, and data boundaries can regress independently.
- Agent route: keep the critical path with the lead; use a separate review lane only for bounded independent verification.
- Browser: use the allowed Chrome path only for live UI, authenticated session, or visual/interaction proof.

## Relevant modules

Load only modules that affect the task:

- `framework/05-architecture/00-clean-architecture.md`
- `framework/08-performance/00-performance-philosophy.md`
- `framework/10-frontend/01-engineering/01-frontend-task-modes.md`
- `framework/11-server-side/02-backend/00-backend-engineering.md`
- `framework/11-server-side/03-database/00-database-engineering.md`
- `framework/11-server-side/01-api/00-api-engineering.md`
- `framework/12-delivery-quality/01-testing/00-testing-and-qa.md`

## Implementation checklist

1. Inspect `git status --short` in every affected repository.
2. Map the ownership chain: route/component, state store, API client, endpoint, service, query, schema, authorization policy, tests.
3. Capture baseline evidence at the user-visible level and at the slowest lower-level boundary.
4. Fix one bottleneck at a time. Avoid bundling unrelated optimizations into one measurement.
5. Preserve contract behavior: filters, sort order, pagination, empty/error/loading states, authorization, freshness, cancellation, and retry behavior.
6. Verify frontend and backend behavior together with contract tests or an equivalent integrated check.
7. Run UEEF evidence gates and completion audit before claiming complete.

## Evidence example

```powershell
.\scripts\new-task-evidence.ps1 -TaskId dashboard-search-fullstack -Tier T3 -SelectedDomain architecture,file-organization,performance,testing -OutputPath .\.ueef\evidence\dashboard-search-fullstack.json
.\scripts\validate-task-evidence.ps1 -Tier T3 -SelectedDomain architecture,file-organization,performance,testing -EvidencePath .\.ueef\evidence\dashboard-search-fullstack.json
```

The evidence must include:

- user-visible behavior before/after;
- API contract or integration proof;
- backend query/response timing with units;
- frontend render/load/interaction timing with units when relevant;
- tests that would fail if permissions, filters, or pagination regressed.

## Completion rule

Do not claim complete because frontend and backend tests passed separately. Completion requires the full requested behavior across the boundary to be proven.
