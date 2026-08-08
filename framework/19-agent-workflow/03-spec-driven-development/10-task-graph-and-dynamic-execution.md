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

State writes are atomic and revision guarded. Scheduling reserves its wave before returning dispatch contracts, which prevents a concurrent scheduler from assigning the same ready task. `start` confirms the reservation and `release` returns a failed dispatch to `READY`. Persisted orchestration also appends fsync-backed `events.jsonl` records for reservation, start, and result boundaries. A graph change invalidates direct resume; update or migrate the state deliberately instead of silently applying old progress to new work.

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

The engine emits dispatch contracts; it does not create hidden agents. A host adapter names the worker, task, prompt, capabilities, allowed write roots, forbidden paths, transport, result protocol, and expected acceptance evidence. The active host creates or reuses workers through the explicit `HostRuntime` boundary. The controller persists reservation, start, and returned result transitions; exceptions, mismatched results, and invalid outcomes are converted into bounded failures.

The UEEF CLI intentionally exposes no upstream workflow execution command. Upstream shell steps are denied during compatibility validation by default, and community/custom executable steps are never loaded automatically.

## Semantic Convergence

Verifier findings may extend a workflow through the bounded convergence contract. Each proposed task must have a unique ID and non-empty `sourceEvidence` links. Existing task definitions cannot be replaced, dependencies must still form a valid DAG, and migrated state preserves completed work, attempts, evidence, tokens, and creation time while refreshing readiness for the new graph revision.

## Productivity Measurement

Productivity comparisons use recorded runs for exactly three modes: `single-agent`, `ueef-static`, and `dynamic-team`. Every sample supplies success, makespan, tokens, retries, conflicts, and rework. The benchmark reports sample counts, success rates, and metric averages; it rejects incomplete mode coverage or fabricated defaults.

## Quality Gate

Passes when the graph validates, Markdown and graph task IDs agree, state belongs to the exact graph digest, the scheduled wave has no ownership conflict, every completion has evidence, retry and budget limits hold, resumed execution reaches the same derived readiness as uninterrupted execution, convergence tasks retain source traceability, and benchmark reports derive only from complete recorded-run inputs.
