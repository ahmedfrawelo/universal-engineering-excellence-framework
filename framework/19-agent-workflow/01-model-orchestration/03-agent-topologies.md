# Agent Topologies

## Single Agent

Use for T0 and T1. T1 defaults to single-agent: the routed implementation lead is the single task agent, including narrow code changes, unless an independent sidecar has positive benefit. The original conversation only owns route dispatch and result integration.

## Lead and Sidecar

Use for T2 when one independent search, test, review, or bounded implementation can run while the lead advances the critical path. The sidecar must own a disjoint output.

## Parallel Specialists

Use for T3 only when at least two independent workstreams exist, such as frontend, backend, security, data, or verification. With one useful delegated stream, use a lead and sidecar. Without positive delegation benefit, retain the single-agent topology. Set disjoint write scopes and integrate once.

## Lead, Workers, Independent Verifier

Use for T4 when delegation benefit exists. The lead owns decisions and integration. Use workers only when at least two independent implementation streams exist; otherwise use the lead plus an independent verifier. Independent verification remains required when the platform exposes a suitable verifier, even when implementation stays with one lead agent. The final verifier must use the fresh-context review protocol and inspect the final diff rather than a worker summary.

## Delegation Benefit Test

Spawn only when all applicable benefit conditions are true; T4 retains independent verification.

- the subtask is concrete and self-contained;
- it materially advances the requested outcome;
- it is not the immediate blocker for the lead's next action;
- context can be bounded without copying the entire conversation;
- expected saved time or context exceeds coordination overhead;
- ownership and completion evidence are explicit.

Limit fan-out to the number of genuinely independent work streams. Close completed agents promptly.
