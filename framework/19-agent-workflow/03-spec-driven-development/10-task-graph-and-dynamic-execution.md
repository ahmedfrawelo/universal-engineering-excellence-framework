# Task Graph and Dynamic Execution

## Purpose

Translate a specification task list into a durable execution graph that can pause, resume, form safe parallel waves, and adjust the requested host team to actual runnable work.

## Graph Contract

`task-graph.json` is the machine-readable companion to `tasks.md`. It must record:

- a stable workflow ID and schema version;
- policy tier, maximum workers, token budget mode, retry limit, and shell policy;
- unique task IDs that match `tasks.md`;
- dependency IDs, requirement IDs, and acceptance IDs;
- effort, risk, priority, capabilities, and parallel-safety intent;
- literal repository-relative write roots and forbidden paths;
- whether the task is read-only.

Unknown dependencies, duplicate IDs, dependency cycles, path traversal, wildcard ownership, and overlapping write/forbidden scopes fail validation. Input is bounded to 500 tasks and 5MB per graph; execution state is bounded to 10MB with per-field evidence and error limits.

## State Contract

Execution state is graph-digest bound and uses these task states:

- `PENDING`: dependencies are incomplete;
- `READY`: every dependency is `DONE`;
- `RESERVED`: a persisted wave has assigned a named host worker but dispatch is not yet confirmed;
- `RUNNING`: a named host worker owns the current attempt;
- `BLOCKED`: a manual condition or failed/blocked dependency prevents progress;
- `DONE`: the worker returned explicit acceptance evidence;
- `FAILED`: the bounded retry allowance is exhausted.

State writes are atomic and revision guarded. Scheduling reserves its wave before returning dispatch contracts, which prevents a concurrent scheduler from assigning the same ready task. `start` confirms the reservation and `release` returns a failed dispatch to `READY`. A graph change invalidates direct resume; update or migrate the state deliberately instead of silently applying old progress to new work.

## Wave Scheduling

The scheduler orders ready tasks by explicit priority and remaining critical-path effort, then builds the largest safe wave within all active constraints:

- tier and policy worker caps;
- remaining token budget;
- available slots after currently running workers;
- isolation for risk-3 work;
- explicit `parallelSafe` intent;
- known write ownership and pairwise scope conflicts;
- forbidden-path boundaries.

Tier sets a ceiling, not a target. The desired team grows when additional non-conflicting work becomes ready and shrinks after work converges. Tasks with unknown write ownership may run alone but never enter a parallel wave.

## Host Boundary

The engine emits dispatch contracts; it does not create hidden agents. A host adapter names the worker, task, prompt, capabilities, allowed write roots, forbidden paths, and expected acceptance evidence. The active host creates or reuses workers and records `start`, `complete`, `fail`, `block`, or `unblock` transitions.

The UEEF CLI intentionally exposes no upstream workflow execution command. Upstream shell steps are denied during compatibility validation by default, and community/custom executable steps are never loaded automatically.

## Quality Gate

Passes when the graph validates, Markdown and graph task IDs agree, state belongs to the exact graph digest, the scheduled wave has no ownership conflict, every completion has evidence, retry and budget limits hold, and resumed execution reaches the same derived readiness as uninterrupted execution.
