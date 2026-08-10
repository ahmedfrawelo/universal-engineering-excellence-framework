# Task Graph and Dynamic Execution

## Purpose

Translate a specification task list into a durable execution graph that can pause, resume, form safe parallel waves, and adjust the requested host team to actual runnable work.

## Graph Contract

`tasks.md` is authoritative. `task-graph.json` is its deterministic route-bound compiled form and must record:

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

State writes are atomic and revision guarded. Every reservation has an execution-bound attempt ID, monotonic lease generation, fencing token, heartbeat, and expiry. Scheduling persists before dispatch, stale receipts fail before mutation, and expired work is reclaimed under a new generation. Persisted orchestration also appends fsync-backed events. A graph change requires canonical replan or explicit migration.

The workflow also has an explicit operator `PAUSED` state. Pause is idempotent, records a
bounded reason, prevents new reservations, and preserves execution/attempt/evidence identity.
Resume removes only the operator pause and recomputes the same graph-derived readiness.

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

Rebalancing may steal only an unstarted `RESERVED` task whose assigned worker is explicitly
unavailable. The replacement must satisfy declared capabilities and receives a new attempt,
lease generation, and fence. A dispatched or `RUNNING` attempt is never stolen.

## Host Boundary

The engine emits identity-bound dispatch contracts and advertises truthful capabilities. The active host creates or reuses workers through the explicit lifecycle boundary. The controller persists dispatch handles, polls, renews supported leases, applies matching results, retries bounded failures, cancels only when supported, closes handles, and resumes crash boundaries idempotently.

The UEEF CLI intentionally exposes no upstream workflow execution command. A safe importer
may expand bounded declarative conditions, fan-out/fan-in, and loops, but rejects shell,
command, prompt, unknown, and unbounded steps. Extensions, presets, and bundles require
versioned provenance, SHA-256, explicit permissions, rollback metadata, deterministic
precedence, and route-policy clamping.

Parent specification hierarchies are bounded and acyclic. A parent cannot roll up `DONE`
until every descendant is `DONE` with independent verification.

## Semantic Convergence

Schema-v2 completion requires independent verification against a diff digest. Changed write sets invalidate prior verifier evidence. Failed verification appends traceable gap tasks to canonical Markdown, recompiles, and migrates completed state. Convergence is capped at three rounds and rejects repeated findings with no progress.

## Productivity Measurement

Recorded comparisons cover `single-agent`, `ueef-static`, and `dynamic-team`, including success, makespan, tokens, retries, conflicts, rework, recovery time, and evidence completeness. The local fixture measures durability overhead and recovery only; it is not a general productivity claim.

## Quality Gate

Passes when the graph validates, Markdown and graph task IDs agree, state belongs to the exact graph digest, the scheduled wave has no ownership conflict, every completion has evidence, retry and budget limits hold, resumed execution reaches the same derived readiness as uninterrupted execution, convergence tasks retain source traceability, and benchmark reports derive only from complete recorded-run inputs.
