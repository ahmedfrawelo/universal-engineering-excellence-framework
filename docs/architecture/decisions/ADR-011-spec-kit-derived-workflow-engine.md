# ADR-011: Spec Kit-Derived Workflow Engine

## Status

Accepted.

## Date

2026-08-08

## Context

UEEF already had durable specification artifacts, task decomposition rules, worker budgets, and convergence gates. It did not have a persistent task-graph runtime that could compute safe execution waves, resume after interruption, or grow and shrink a host team from actual ready work. Merely invoking an external Spec Kit installation would leave version, policy, security, and update behavior outside UEEF ownership. Reimplementing every upstream workflow concept without preserving the real source would also make compatibility claims difficult to audit.

Spec Kit's workflow engine is useful upstream code, but its documented shell steps execute with the user's privileges and interpolation is not a security boundary. External custom steps and community workflows are also executable code. Those surfaces cannot become implicit UEEF behavior.

## Decision

Adopt a derived-engine architecture with a strict ownership boundary.

1. Vendor the official Spec Kit `v0.16.1` source at commit `ad4104b56c219b0a27bac06547d1a3c7d6a0dbd6` under `engines/spec-workflow/upstream/spec-kit/` without UEEF modifications.
2. Record release, commit, license, file count, included roots, and an aggregate content digest in `engines/spec-workflow/UPSTREAM.json`.
3. Keep all UEEF behavior under `engines/spec-workflow/ueef/`; upstream refreshes replace the snapshot rather than mixing patches into it.
4. Represent executable work in `task-graph.json` as a validated DAG with explicit dependencies, requirements, acceptance IDs, capabilities, risk, effort, read/write ownership, and retry limits.
5. Persist graph-bound execution state atomically. Refuse resume after graph drift, require optimistic revision matches for writes, reserve scheduled tasks before returning dispatch contracts, and require evidence before `DONE`.
6. Derive `READY` and dependency-blocked states mechanically. Bound retries and propagate terminal dependency failures.
7. Schedule waves by priority and critical-path effort, then constrain them by tier, worker cap, token budget, risk isolation, parallel-safety declaration, and write-scope conflicts.
8. Emit host dispatch contracts for Codex, Claude, or a generic host. The engine does not secretly create agents; the host owns dispatch and returns transition evidence.
9. Deny upstream shell-step definitions by default. The bridge only validates upstream YAML and exposes no run command. External custom steps, community workflows, and extensions are not loaded automatically.
10. Extend the existing `.ueef/specs/<id>` generator and validator so Markdown tasks and `task-graph.json` are one consistent workflow.

## Consequences

- UEEF can use real upstream code for compatibility checks while policy and security remain locally owned.
- Execution can resume deterministically and reject stale or concurrent state updates.
- Team size follows runnable, non-conflicting work instead of being inferred directly from tier.
- High-risk or unscoped work is serialized; bounded, disjoint work can form parallel waves.
- Full upstream compatibility validation requires the optional dependencies declared by the engine's `upstream` extra. Core graph scheduling uses only the Python standard library.
- Updating Spec Kit requires replacing the snapshot, updating provenance and license evidence, rerunning upstream validation, and reviewing the UEEF boundary for new executable surfaces.

## Rollback

Remove `engines/spec-workflow/`, the engine wrapper and tests, and `task-graph.json` integration from the spec generator/validator as one unit. Restore the prior attribution and Pack 60 documentation. Existing Markdown specification artifacts remain readable, but execution-state files must not be interpreted without their graph-bound engine.
