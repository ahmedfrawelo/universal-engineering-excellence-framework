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
5. Run a completion audit that maps every acceptance criterion to a result.

## Continuation Rules

- A failed check triggers diagnosis and repair when it is caused by or directly blocks the requested work.
- An unrelated historical failure is recorded and narrowed around; it does not authorize unrelated cleanup.
- Nearing a budget or encountering difficulty is not a blocker.
- Ask for user input only when a missing choice materially changes the result or new authority is required.

## Required Evidence

- Current plan states and the acceptance criterion owned by each step.
- Focused test or inspection evidence for every changed behavior.
- Final gate results, skipped-check reasons, residual risks, and owners.

## Invalid Completion

- Reporting intent, code presence, or compilation as proof of requested behavior.
- Marking a goal blocked while safe in-scope work remains.
- Hiding failed or unavailable validation behind a vague success summary.
