# Refactoring Decision Graph

## Decision Question

Which option satisfies the required **refactoring** outcome while controlling preserved behavior, seam selection, incremental steps, debt reduction, and rollback?

## Flow

1. Define the observable outcome, constraints, owner, and evidence threshold.
2. If the repository already has a conforming refactoring mechanism, extend it and verify compatibility; otherwise continue.
3. List the viable options and reject any that cannot make failure, rollback, or ownership explicit.
4. Compare the remaining options on preserved behavior, seam selection, incremental steps, debt reduction, and rollback.
5. Select the smallest reversible option that meets current requirements; require an ADR when the choice changes a shared or public boundary.
6. Stop with BLOCKED when a required fact, authority, recovery path, or validation environment is missing.

## Default

Prefer the nearest tested project convention. Introduce a new abstraction only when it creates a real ownership boundary or removes demonstrated repeated complexity.

## Required Evidence

- The selected and rejected branches, with the evidence used at each branch.
- characterization tests plus focused complexity and behavior comparisons.
- A revisit trigger for assumptions likely to change.

## Invalid Outcomes

- A choice based only on memory or generic preference.
- An irreversible path without explicit authority and recovery evidence.
- A decision recorded without proving the affected behavior.
