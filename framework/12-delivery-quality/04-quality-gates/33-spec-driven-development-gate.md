# Spec-Driven Development Gate

## Purpose

This gate prevents substantial implementation from drifting away from requirements, plans, tasks, and evidence.

## Pass Criteria

- The task was classified for whether spec-driven development applies.
- A current specification or equivalent requirement artifact exists for broad, ambiguous, or high-impact work.
- Ambiguities are resolved, explicitly carried as assumptions, or escalated before dependent implementation.
- The technical plan traces decisions to requirements and project principles.
- The task breakdown has dependency order, validation checks, and safe parallelization boundaries.
- Consistency analysis confirms no requirement, plan decision, task, code change, or final claim is orphaned.
- Completion evidence matches the acceptance criteria.

## Fail Conditions

- Implementation starts from a broad prompt without requirements or acceptance criteria.
- Hidden assumptions drive behavior.
- Tasks are not traceable to the plan.
- Tests are used as broad proof without checking acceptance coverage.
- Final response claims completion without convergence evidence.
