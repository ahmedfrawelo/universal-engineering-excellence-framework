# Correctness Cost and Approval

Performance improvements must preserve product correctness and operational safety.

## Correctness and Security Safeguards

For every optimization candidate, evaluate:

- data correctness, stale-data risk, authorization risk, tenant leakage risk, cache-key isolation, transaction consistency, ordering stability, pagination consistency, duplicate or missing rows, deleted or updated row behavior, concurrent writes, eventual consistency, feature flags, rollback, migration safety, and production deployment safety

Never improve speed by weakening security, returning incorrect data, exposing another tenant's records, or silently changing business behavior.

## Cost and Operations

Report:

- implementation effort, infrastructure cost, cloud cost, storage cost, Redis memory cost, bandwidth cost, maintenance burden, monitoring burden, deployment complexity, failure modes, rollback complexity, vendor lock-in, useful lifetime, and scaling limit

## Approval Gate

Audit mode ends with a numbered proposed implementation order and then stops.

Do not edit code, install packages, add indexes, change SQL, modify Redis, alter infrastructure, or create migrations until the user explicitly approves the plan.
