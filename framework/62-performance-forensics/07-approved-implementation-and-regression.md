# Approved Implementation and Regression

Use this module only after the user approves a performance plan.

## Implementation Rules

1. Implement the smallest approved package first.
2. Preserve behavior and security before optimizing deeper.
3. Keep risky changes reversible with feature flags, migrations that can roll back, or documented rollback steps.
4. Measure before and after each meaningful slice.
5. Reject or revert changes that do not meet success thresholds or introduce correctness, authorization, tenant, data-loss, or reliability risk.

## Required Post-Change Evidence

- baseline and after timing
- p50 and p95 where practical
- affected tests
- correctness and authorization checks
- payload or SQL evidence when relevant
- monitoring metric to watch after deployment
- rollback procedure

## Completion Rule

Do not claim a performance fix succeeded unless measurements improve the approved target without a new regression.
