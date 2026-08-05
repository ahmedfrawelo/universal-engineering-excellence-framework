# Upgrade Decision And Execution

## Apply Automatically

Apply a compatible patch or minor upgrade when the user authorized project improvement, the support range permits it, release notes show no material migration, security and license checks pass, lockfile changes are bounded, and build plus relevant tests can verify it.

## Propose Before Mutation

Request an explicit decision for major versions, runtime or language target changes, database or schema migrations, infrastructure/provider changes, removed APIs, authentication/security behavior, substantial bundle or hosting impact, unsupported transitive constraints, or upgrades requiring coordinated deployment.

## Upgrade Report

Record current and target versions, source of truth, support status, motivation, breaking changes, migration steps, affected owners, security/performance impact, lockfile or artifact changes, rollout order, rollback, and verification commands.

Upgrade one coherent dependency cluster at a time. Regenerate lockfiles with the repository package manager, preserve reproducibility, run compatibility and runtime checks, and do not hide unrelated dependency churn.
