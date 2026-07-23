# Agent and Model Orchestration System

## Purpose

Route every task to the smallest capable model class and agent topology while preserving engineering quality, security, and truthful verification.

## Mandatory Runtime Sequence

1. Classify complexity and risk before substantial work.
2. Check whether delegation can run independently and save more than it costs.
3. Select the minimum model capability that satisfies the risk floor.
4. Keep the critical path with the lead agent; delegate bounded, non-overlapping side work.
5. Give each child a minimal context packet, explicit ownership, deliverable, and stop condition.
6. Escalate capability after ambiguity, failed verification, expanding scope, or discovered risk.
7. Close agents when their result is integrated.
8. Verify the combined result at the level required by the task, not by the model used.

## Invariants

- Every task passes the router, including conversational and trivial work.
- `medium` is the economical default, not a hard ceiling. A recorded T3/T4 or high-ambiguity route may request a platform-supported higher level; never lower the risk floor to avoid escalation, and never prohibit a higher inherited level selected by the platform.
- Every non-trivial task executes the route selector or records an equivalent classification before substantial work.
- T1 code changes default to a single lead agent. Spawn a bounded child only when an independent sidecar materially improves the result or latency; T2–T4 use the same benefit test, with T4 retaining independent verification.
- Before the first project command or edit, publish one Visible pre-command route line: `Agent route: <tier> | Agent: spawned <id or nickname>` or `Agent route: <tier> | Agent: not spawned - <reason>`.
- `NO_INDEPENDENT_WORK` is valid for a narrow code-changing T1 task. `TOOL_UNAVAILABLE` remains a valid capability reason; `CRITICAL_PATH_ONLY` is valid when delegation would not improve the requested outcome.
- A final UEEF pass claim is invalid when the route line is missing, or when a route that actually spawned a child lacks that child’s bounded-result evidence. A single-agent T1 route with `NO_INDEPENDENT_WORK` needs no child-agent evidence.
- Routing does not imply spawning. The lead agent is the single-agent topology.
- Model names are runtime mappings, not durable policy. Capability classes are durable.
- Security, authorization, production, destructive operations, data migrations, architecture, and incident response have mandatory capability floors.
- Delegation may reduce elapsed time or context size, but never transfers final accountability from the lead agent.
- Agents do not duplicate the same investigation or edit overlapping files without an explicit integration plan.

## Gate

Pass only when the selected route is justified, context is bounded, work is not duplicated, escalation triggers are active, and verification matches risk.
