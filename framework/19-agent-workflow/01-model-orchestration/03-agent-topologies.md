# Agent Topologies

## Single Agent

Use for T0 and T1. T1 defaults to single-agent: the routed implementation lead is the single task agent, including narrow code changes, unless an independent sidecar has positive benefit. The original conversation only owns route dispatch and result integration.

An internal worker or verifier is not a user-visible Codex task. Leader/Worker delegation uses bounded sub-agent execution and returns results to the lead in the current task. Creating or forking a sidebar task is allowed only when the user explicitly requests a separate task; model routing, smoke tests, token economy, and ordinary delegation never imply that permission.

## Lead and Sidecar

Use for T2 when one independent search, test, review, or bounded implementation can run while the lead advances the critical path. The sidecar must own a disjoint output.

The sidecar must receive an execution-spec slice: outcome, owner paths, forbidden paths, token budget mode, output cap, and evidence requirement. The lead integrates the sidecar result once and does not ask the sidecar to keep narrating unchanged status.

## Parallel Specialists

Use for T3 only when at least two independent workstreams exist, such as frontend, backend, security, data, or verification. With one useful delegated stream, use a lead and sidecar. Without positive delegation benefit, retain the single-agent topology. Set disjoint write scopes and integrate once.

Parallel specialists are for real disjoint ownership, not for duplicating the same scan with more models. Each specialist must have a different owner, artifact, or verification lane.

## Lead, Workers, Independent Verifier

Use for T4 when delegation benefit exists. The lead owns decisions and integration. Use workers only when at least two independent implementation streams exist; otherwise use the lead plus an independent verifier. Independent verification remains required when the platform exposes a suitable verifier, even when implementation stays with one lead agent. The final verifier must use the fresh-context review protocol and inspect the final diff rather than a worker summary.

The lead plans and reviews; workers execute scoped tasks. The verifier challenges the final result against the execution spec, acceptance criteria, and current diff.

## Delegation Benefit Test

Spawn only when all applicable benefit conditions are true; T4 retains independent verification.

- the subtask is concrete and self-contained;
- it materially advances the requested outcome;
- it is not the immediate blocker for the lead's next action;
- context can be bounded without copying the entire conversation;
- expected saved time or context exceeds coordination overhead;
- ownership and completion evidence are explicit.
- worker output can be capped without losing the evidence needed for completion.

Limit fan-out to the number of genuinely independent work streams. Close completed agents promptly.
