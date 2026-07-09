# Caching Decision Graph

## Purpose
Use this decision graph to choose the smallest architecture or implementation move that satisfies the requirement while preserving maintainability, security, performance, and future extension.

## Decision Flow
1. Clarify the user-visible outcome and the non-negotiable constraints.
2. Inspect the existing implementation and identify established local patterns.
3. Decide whether the change belongs in existing code, a new module, a shared abstraction, configuration, documentation, or operational tooling.
4. Evaluate impact on public contracts, data shape, migrations, deployment, and rollback.
5. Choose the option with the lowest long-term complexity that still meets the acceptance criteria.
6. Validate with the strongest available automated checks and targeted manual review.

## Alternatives
- Reuse the existing pattern when it is clear, tested, and still fits the new behavior.
- Extend a nearby abstraction when duplication would otherwise become meaningful.
- Create a new module when ownership, lifecycle, or dependency direction differs.
- Defer a broad redesign when the request is narrow and the current architecture can safely absorb it.
- Escalate to an ADR when the decision affects multiple teams, deployment topology, data contracts, or security posture.

## Tradeoffs
- Speed favors local edits; durability favors clearer boundaries and explicit contracts.
- Shared abstractions reduce duplication only when the behavior is genuinely common.
- New dependencies can reduce implementation time but add supply-chain, maintenance, and bundle risk.
- Caching and denormalization improve latency only when invalidation is designed first.

## Risks
- Hidden coupling to existing state or data contracts.
- Performance regressions caused by extra rendering, queries, network calls, or serialization.
- Security regressions from broad permissions, unvalidated input, or unsafe defaults.
- Migration failures or irreversible data changes.
- UX inconsistency from inventing patterns that already exist in the product.

## Recommended Default
Start by following the nearest established project convention. Add a new abstraction only when it removes real repeated complexity or creates a required ownership boundary.

## Exceptions
Override the default when security, data integrity, regulatory, accessibility, or production reliability requirements demand a more explicit design.

## Failure Modes
- The decision is based on memory instead of current code inspection.
- The chosen approach creates duplicate UI, duplicate business logic, or hidden global state.
- Validation is limited to compilation while the risky behavior remains untested.

## Quality Gate
Record the chosen branch, rejected alternatives, evidence inspected, and validation performed. A decision without evidence is partial, not complete.
