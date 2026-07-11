# Agent Topologies

## Single Agent

Use for T0 and most T1 tasks. This is still agent-routed execution. Spawning a child is prohibited when coordination would cost more tokens or time than the work.

## Lead and Sidecar

Use for T2 when one independent search, test, review, or bounded implementation can run while the lead advances the critical path. The sidecar must own a disjoint output.

## Parallel Specialists

Use for T3 when two or more independent domains exist, such as frontend, backend, security, data, or verification. Set disjoint write scopes and integrate once.

## Lead, Workers, Independent Verifier

Use for T4. The lead owns decisions and integration. Workers own bounded slices. A verifier that did not implement the critical path reviews behavior, risk, and evidence.

## Delegation Benefit Test

Spawn only when all are true:

- the subtask is concrete and self-contained;
- it materially advances the requested outcome;
- it is not the immediate blocker for the lead's next action;
- context can be bounded without copying the entire conversation;
- expected saved time or context exceeds coordination overhead;
- ownership and completion evidence are explicit.

Limit fan-out to the number of genuinely independent work streams. Close completed agents promptly.
