# Enterprise Project Example

This example shows the minimum UEEF workflow for high-risk enterprise work: identity, authorization, tenancy, production data, regulated workflows, deployment, rollback, observability, or cross-team platform changes.

## Scenario

User request:

```text
Change tenant-aware permissions and prove no cross-tenant data exposure is possible.
```

## Route

- Intent: enterprise security and production-risk behavior.
- Tier: T4 when production, privacy, security, migration, or irreversible external state is involved; T3 only for local non-production design or documentation changes.
- Agent route: lead agent keeps the critical path; independent review is required for eligible T4 completion.
- Browser: use the allowed Chrome path only when authenticated browser behavior is part of the proof.

## Relevant modules

- `framework/07-security/00-security-by-default.md`
- `framework/11-backend/00-backend-engineering.md`
- `framework/12-database/00-database-engineering.md`
- `framework/20-enterprise/00-enterprise-system.md`
- `framework/45-identity-access-application-models`
- `framework/17-testing/00-testing-and-qa.md`
- `framework/27-quality-gates/final-gate.md`

## Implementation checklist

1. Inspect source, branch, status, deployment policy, and existing ownership.
2. Identify trust boundaries, actors, assets, tenant boundaries, authorization checks, audit logs, rollback strategy, and data migration risk.
3. Prefer local characterization tests before modifying shared security or data access code.
4. Prove denied access, allowed access, boundary cases, and failure behavior.
5. Run security, testing, runtime, and final evidence gates.
6. Do not push, deploy, release, migrate, or clean data unless explicitly requested.

## Evidence example

```powershell
.\scripts\new-task-evidence.ps1 -TaskId tenant-permission-change -Tier T4 -SelectedDomain security,testing,production,final -OutputPath .\.ueef\evidence\tenant-permission-change.json
.\scripts\validate-task-evidence.ps1 -Tier T4 -SelectedDomain security,testing,production,final -EvidencePath .\.ueef\evidence\tenant-permission-change.json
```

## Completion rule

Enterprise completion requires current evidence for the requested behavior itself, no known problems, no remaining work, and an eligible fresh review when T4 applies.
