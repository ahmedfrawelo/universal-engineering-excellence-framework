# Backend Project Example

This example shows the minimum UEEF workflow for a backend change such as an API endpoint, service rule, database access path, queue worker, or authorization boundary.

## Scenario

User request:

```text
Fix the slow project search endpoint and prove the requested behavior.
```

## Route

- Intent: backend behavior and performance fix.
- Tier: T2 for a scoped backend change; T3 if it touches shared data access, migrations, production risk, or multiple services.
- Agent route: lead agent only unless independent database/API review can run in parallel.
- Browser: not used unless the requested proof requires a live UI.

## Relevant modules

Load only modules that affect the task:

- `framework/08-performance/00-performance-philosophy.md`
- `framework/11-server-side/02-backend/00-backend-engineering.md`
- `framework/11-server-side/03-database/00-database-engineering.md`
- `framework/11-server-side/01-api/00-api-engineering.md`
- `framework/12-delivery-quality/01-testing/00-testing-and-qa.md`

## Implementation checklist

1. Inspect `git status --short` and preserve unrelated work.
2. Locate the endpoint owner, service owner, query owner, tests, and existing performance conventions.
3. Measure the current constrained path before optimizing. Record command, dataset size, and timing.
4. Fix the bottleneck without weakening correctness, authorization, validation, or freshness.
5. Add or update the nearest behavior test.
6. Re-measure the same path and keep the change only if it improves beyond noise and tests stay green.
7. Run the relevant project tests plus UEEF evidence gates.

## Evidence example

```powershell
.\scripts\new-task-evidence.ps1 -TaskId backend-search-performance -Tier T2 -SelectedDomain performance,testing -OutputPath .\.ueef\evidence\backend-search-performance.json
.\scripts\validate-task-evidence.ps1 -Tier T2 -SelectedDomain performance,testing -EvidencePath .\.ueef\evidence\backend-search-performance.json
```

The evidence must include:

- baseline and post-change timing with units;
- exact test commands and exit codes;
- affected endpoint/service/query files;
- residual risks with owner, mitigation, and trigger.

## Completion rule

Do not claim complete because the build passed. Completion requires the endpoint behavior and the measured performance path to be proven against the original request.
