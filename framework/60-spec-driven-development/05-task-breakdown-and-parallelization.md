# Task Breakdown and Parallelization

## Purpose

Tasks convert the plan into executable work while preserving dependency order and safe parallelism.

## Task Rules

- Each task must have an owner area, input artifact, output artifact, validation command or check, and done condition.
- Order tasks by dependency: contracts and tests before implementation where practical; shared foundations before consumers; migrations before dependent code.
- Mark tasks that are safe to run in parallel only when their write sets do not overlap and their dependencies are satisfied.
- Do not create task items that are vague verbs such as "improve", "clean", or "finish" without a concrete deliverable.
- Keep task lists current. When implementation discovers missing work, append or revise tasks before continuing.

## Parallelization Checks

- Files or modules are disjoint.
- Shared contracts are already defined.
- No task depends on unmerged output from a parallel task.
- Validation can be run independently or has a defined integration gate.
