# Consistency Analysis and Checklists

## Purpose

Before implementation and before completion, the assistant must check that the specification, plan, tasks, code, tests, and final claims agree.

## Consistency Checks

- Every requirement has an implementation path or is explicitly deferred.
- Every implementation task traces to a requirement, plan decision, bug, or approved scope change.
- Every acceptance criterion has evidence.
- The plan does not introduce behavior outside the specification.
- The task list does not omit contracts, migrations, tests, UI states, security checks, or operational needs required by the plan.
- Tests and validation cover the actual acceptance criteria, not only incidental build health.

## Checklist Rules

- Use checklists as tests for English: completeness, clarity, consistency, measurability, and traceability.
- A checklist item is not complete because a related command passed; it is complete only when the evidence matches the item.
- If a checklist finds a contradiction, fix the artifact that owns the truth first.
- Run checklist/analyze before implementation for broad work and again before completion when code, tests, or user updates changed the plan.
- Treat task-to-issue or external tracker export as a derived artifact. It must not become more authoritative than the local spec, plan, tasks, and convergence record.

## Minimum Analyze Questions

- Does every requirement have at least one acceptance criterion?
- Does every acceptance criterion have a validation path?
- Does every plan decision map to a requirement, constraint, or recorded assumption?
- Does every task include requirements, dependencies, evidence, and done criteria?
- Are any implementation details present in the specification where only what/why should appear?
- Are any external issues, bundles, presets, or extensions referenced without provenance and install boundaries?
