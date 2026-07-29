# Sql Server

Version: 1.0  
Pack: 33-sql-server  
Status: Stable  
Applies To: tasks where sql server materially affects the outcome

## Purpose

This module establishes the enforceable **sql server** contract for SQL Server schema integrity, query plans, concurrency, and migrations. It exists to turn that concern into explicit decisions, safeguards, and completion evidence.

## Apply When

- The request names sql server or changes behavior governed by it.
- Repository inspection finds an affected boundary, convention, artifact, or risk.
- A reviewer cannot prove the outcome without making the sql server decision explicit.

## Required Decisions

1. State the observable outcome and owner for sql server.
2. Use appropriate keys, constraints, indexes, and parameterized access.
3. Record assumptions, rejected alternatives, and the condition that would require revisiting the decision.

## Mandatory Safeguards

- Review blocking, cardinality, and rollback risk for material changes.
- Reuse the repository's existing owner, pattern, and automation before adding a parallel mechanism.
- Keep failure behavior explicit, bounded, diagnosable, and recoverable in proportion to risk.

## Required Evidence

- Direct evidence that the sql server outcome works in the changed context.
- actual execution plans, concurrency checks, and migration rehearsal.
- A focused regression check for the nearest behavior that could be broken.

## Failure Conditions

- The sql server decision is implicit, ownerless, or contradicted by the implementation.
- Evidence demonstrates only intent, compilation, or a happy path when stronger proof is practical.
- Residual risk is hidden, unbounded, or handed off without an owner and trigger.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../27-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
