# performance philosophy

Version: 1.0  
Pack: 08-performance  
Status: Stable  
Applies To: tasks where performance philosophy materially affects the outcome

## Purpose

This module establishes the enforceable **performance philosophy** contract for measurable latency, throughput, resource, and responsiveness goals. It exists to turn that concern into explicit decisions, safeguards, and completion evidence.

## Apply When

- The request names performance philosophy or changes behavior governed by it.
- Repository inspection finds an affected boundary, convention, artifact, or risk.
- A reviewer cannot prove the outcome without making the performance philosophy decision explicit.

## Required Decisions

1. State the observable outcome and owner for performance philosophy.
2. Set a budget before optimizing and measure the actual constrained path.
3. Record assumptions, rejected alternatives, and the condition that would require revisiting the decision.

## Performance Workflow

1. Define the constrained path in user or operator terms: route load, command latency, graph build, query response, API p95, memory ceiling, bundle size, or interaction latency.
2. Capture a baseline using the same command or browser path that will be used after the change. Include units, sample count, warm/cold state, and machine-sensitive assumptions.
3. Identify the bottleneck before editing. If the measurement does not point to a bottleneck, do not keep speculative complexity.
4. Change one performance lever at a time where practical: caching, incremental work, bounded traversal, direct executable invocation, pagination, projection, lazy loading, memoization, or reduced output.
5. Re-measure under the same conditions. Keep the change only when correctness gates pass and the result beats noise or an explicit budget.
6. Record reverted or rejected attempts when they are plausible enough that another agent may retry them later.

## Common UEEF Performance Boundaries

- Loader and routing: reduce mandatory reading; select only relevant modules.
- Repository intelligence: prefer cached state, bounded queries, direct local executable invocation, and ignored generated/vendor directories.
- Validation: keep default output quiet and make nested detail opt-in.
- Runtime sync: copy only required runtime-owned source and verify drift after sync.
- Browser work: use it only when the requested behavior needs browser evidence.
- Documentation examples: give exact commands so agents do not spend context discovering basic workflow.

## Minimum Evidence Shape

For a performance-related change, evidence must include:

- baseline command or observation with a numeric value and unit;
- post-change command or observation with a numeric value and unit;
- exact changed mechanism;
- nearest correctness or regression check;
- decision to keep or revert the optimization.

## Mandatory Safeguards

- Do not trade correctness, security, or accessibility for unmeasured speed.
- Reuse the repository's existing owner, pattern, and automation before adding a parallel mechanism.
- Keep failure behavior explicit, bounded, diagnosable, and recoverable in proportion to risk.

## Required Evidence

- Direct evidence that the performance philosophy outcome works in the changed context.
- repeatable baseline and post-change measurements against a stated budget.
- A focused regression check for the nearest behavior that could be broken.
- For command/runtime optimizations, include wall-clock before/after measurements from the same command and root.

## Failure Conditions

- The performance philosophy decision is implicit, ownerless, or contradicted by the implementation.
- Evidence demonstrates only intent, compilation, or a happy path when stronger proof is practical.
- Residual risk is hidden, unbounded, or handed off without an owner and trigger.
- An optimization is kept after a neutral or worse measurement without a documented correctness reason.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../27-quality-gates/00-quality-gate-system.md

## Completion Contract

Pass only when the decision, implementation, evidence, and remaining risk agree. Otherwise report the exact failed condition and required next action.
