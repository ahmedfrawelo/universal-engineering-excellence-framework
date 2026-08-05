# Task Lifecycle

Version: 1.1
Pack: 01-core  
Status: Stable  
Applies To: tasks with implementation, verification, or an explicit goal

## Purpose

This module defines when a task starts, continues, completes, or becomes blocked. Its primary protection is against premature completion and false blocker claims.

## Goal State Machine

- `ACTIVE -> COMPLETE` only when the requested outcome is satisfied, no required work remains, applicable gates pass or are explicitly accepted, and verification is recorded.
- `ACTIVE -> BLOCKED` only when the blocker is external or user-only, no meaningful local work remains, and an external state change is required.
- `ACTIVE -> final response` is allowed when the bounded requested outcome is complete; otherwise active implementation continues through commentary.
- Compile or test failures, incomplete implementation, regressions, and repeated unsuccessful patches keep the goal `ACTIVE`.
- A thread-scoped browser-control failure keeps the goal `ACTIVE` while safe same-tab evidence or recovery remains possible.
- `COMPLETE` is invalid when any required acceptance criterion, plan item, implementation, test, or verification remains.

## Execution Contract

1. Translate the request into observable acceptance criteria and exclusions.
2. Inspect the affected owner, constraints, and validation surfaces.
3. Plan dependent work in order; keep only one dependent step in progress.
4. Implement and verify each slice, updating the plan from actual evidence.
5. When implementation is complete, announce that implementation is complete and that goal review has started. Keep `GoalStatus: ACTIVE`; implementation completion is not goal completion.
6. Start a completion checklist from the first character of the original goal. Each requirement must be compared against an inventory of what was actually implemented and observed, its current acceptance evidence, the requested implementation, and the best feasible outcome within the inspected constraints. A prose reread without this comparison cannot pass.
7. Review regressions on every changed surface. Fix every regression caused by the task, then rerun affected checks. Record unrelated findings with evidence and an out-of-scope reason, but do not repair or chase them unless they directly block verification or the user expands scope.
8. Generate a schema-version-2 completion-audit artifact from `framework/21-framework-resources/01-templates/completion-audit-template.json`. Preserve the original goal in `sourceReview.sourceText`, cover all non-whitespace text with contiguous exact review units, classify and link every unit, map every explicit requirement to acceptance criteria and current evidence, and validate it with `scripts/validate-completion-audit.ps1`.
9. Only after the checklist, best-feasible review, task-regression review, and all gates pass may the goal become `COMPLETE`. Say the goal is complete and stop; do not ask whether anything is missing or whether the user wants more work.

An explicit user statement such as "I need something before you finish" creates a pending before-finish commitment even when its details are not yet supplied. Keep the goal `ACTIVE`, ask the user for that promised detail, and record the commitment until it is clarified, implemented or otherwise resolved, and reviewed. This required pre-completion clarification is not a forbidden post-completion follow-up question.

For a multi-step active goal, each material progress update is a structured lifecycle event. It must include the current understanding, phase, named current step, current-step percentage, conservative overall percentage, new evidence, current action, and next gate. The current-step and overall percentages have different scopes and cannot replace one another.

## Goal Update Routing

Do not abandon the active step merely because the user updated the goal. First record the update, its acceptance criteria, impact, and route in the plan.

- `CURRENT_STEP`: merge it into the current step and continue that step.
- `PRIOR_STEP_CORRECTION`: record a resume point, pause safely, reopen and verify the prior step, then return to the saved current step.
- `FUTURE_STEP`: preserve current work and queue the update with target step, order, dependencies, and acceptance criteria.
- `INVALIDATES_CURRENT_WORK`: record a resume point, pause at a safe boundary, and replan because continuing would create invalid or unsafe work.
- `CONFLICT_OR_AMBIGUOUS`: preserve the current state and ask the user for the material decision before proceeding.

Every update must remain traceable until resolved. Completion requires no pending update and no open resume point.

The goal review compares classified updates and literal requirements to actual implementation. Any absent requested behavior is recorded in `missingImplementation`, implemented in the correct routed step, and compared again. `COMPLETE` requires every received update classified and both `missingImplementation` and `untracedImplementation` empty.

## Continuation Rules

- A failed check triggers diagnosis and repair when it is caused by or directly blocks the requested work.
- An unrelated historical failure is recorded and narrowed around; it does not authorize unrelated cleanup.
- Nearing a budget or encountering difficulty is not a blocker.
- Ask for user input only when a missing choice materially changes the result or new authority is required.

## Required Evidence

- Current plan states and the acceptance criterion owned by each step.
- Focused test or inspection evidence for every changed behavior.
- A checked completion checklist for every explicit requirement, plus a passing review of the requested implementation and best feasible outcome.
- A reverse trace from every actual implementation inventory item to one or more requirements; untraced implementation blocks completion.
- A changed-surface regression review with no remaining task-caused regression; unrelated findings remain visible and out of scope.
- Final gate results, skipped-check reasons, residual risks, and owners.
- A passing schema-version-2 completion audit with complete verbatim source coverage, no remaining work, and no known problems. Build success, test success, code presence, or a summary-only claim cannot substitute for requirement-level evidence.

## Invalid Completion

- Reporting intent, code presence, or compilation as proof of requested behavior.
- Marking a goal blocked while safe in-scope work remains.
- Hiding failed or unavailable validation behind a vague success summary.
