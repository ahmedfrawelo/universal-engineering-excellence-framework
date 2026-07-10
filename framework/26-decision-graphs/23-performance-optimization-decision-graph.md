# Performance Optimization Decision Graph

Version: 1.1.0

## Inputs

- measured bottleneck; user impact; percentile; resource cost; growth model

## Alternatives

- remove work; change algorithm; batch; cache; parallelize; precompute; scale

## Tradeoffs

Choose the option that preserves semantics and ownership while meeting measured user, security, and operational needs. Prefer reversible changes when evidence is incomplete.

## Risks

- premature caching causes staleness; parallelism overloads dependencies; micro-optimization hides structural waste

## Recommended Default

remove unnecessary work first, then optimize the measured critical path against a budget.

## Exceptions

An exception requires project evidence, an owner, a review date, bounded impact, and a regression test.

## Failure Modes

- Selecting by visual preference without repository evidence.
- Applying a local patch that bypasses the shared contract.
- Declaring success without testing the relevant edge and failure paths.

## Related Modules

- framework/46-design-system-consistency-reuse/09-reuse-decision-engine.md
- framework/47-theme-responsive-interaction-security-performance/README.md
