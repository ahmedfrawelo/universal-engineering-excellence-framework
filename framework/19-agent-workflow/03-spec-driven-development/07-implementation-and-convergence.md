# Implementation and Convergence

## Purpose

Implementation is not finished until code converges with the specification, plan, tasks, and validation evidence.

## Rules

- Implement from the task list and keep changes scoped to the current task.
- When code reveals missing requirements, update the specification or task list instead of silently widening scope.
- When the user changes the goal, record the update route and preserve the active resume point before changing execution. Completion convergence includes every received update, with no pending update or open resume point.
- When tests reveal plan flaws, update the plan and tasks before retrying.
- When a task is complete, record the evidence that proves the acceptance criteria it covers.
- Before final response, run a convergence pass across spec, plan, tasks, code, tests, and residual risks.
- Check that the actual context and worker usage stayed within the recorded token/worker budget, or that the spec was updated when the budget changed.
- If a Spec Kit-style `implement` request arrives, execute the current UEEF task list and do not invent new tasks unless convergence exposes a requirement gap.
- If a Spec Kit-style `converge` request arrives, audit drift across specification, plan, tasks, implementation, tests, and evidence; append explicit remaining tasks instead of declaring completion from partial alignment.

## Completion Criteria

- No unresolved material ambiguity remains.
- No implemented behavior is untraced to a requirement or approved change.
- No acceptance criterion lacks evidence.
- No final claim exceeds the verified scope.
- No token-saving shortcut removed required acceptance evidence or final review.
- Residual risks are concrete and actionable.
- Any remaining task-to-issue export is either completed with explicit authorization or recorded as out of scope.
