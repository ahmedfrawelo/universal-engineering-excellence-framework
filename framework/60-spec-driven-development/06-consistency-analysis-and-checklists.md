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
