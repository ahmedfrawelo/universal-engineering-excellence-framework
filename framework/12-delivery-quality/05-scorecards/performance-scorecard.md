# Performance Scorecard

## Scale

- 0 - absent, contradicted, or unsafe.
- 1 - acknowledged but materially incomplete or unverified.
- 2 - implemented with adequate evidence and minor bounded gaps.
- 3 - complete, maintainable, and supported by strong reproducible evidence.

## Dimensions

Score each dimension from 0 to 3:

1. **Outcome fit** - the performance result satisfies the actual requirement.
2. **Domain completeness** - the work addresses the user or system budget, constrained path, baseline, bottleneck, and regression threshold.
3. **Project consistency** - ownership, naming, boundaries, and reuse match the repository.
4. **Failure safety** - errors, edge cases, rollback, and observability are explicit.
5. **Evidence quality** - repeatable before-after measurements under representative load is reproducible.
6. **Change durability** - future modification is local, understandable, and guarded against regression.

## Threshold

Pass at 15/18 or higher. Any zero, failed required gate, hidden high risk, or missing critical evidence is an automatic fail regardless of total.

## Record

For every score below 3, cite the gap, impact, owner, and next action. Record the total, automatic-fail status, evidence links, and final PASS or FAIL decision.
