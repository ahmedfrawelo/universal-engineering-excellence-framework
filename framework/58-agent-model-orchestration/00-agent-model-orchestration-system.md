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
- The reasoning ceiling is `medium` for the lead and every child agent. No route may emit or request a higher level.
- Every non-trivial task executes the route selector or records an equivalent classification before substantial work.
- A T2-T4 route with available agent tooling and positive independent delegation benefit must spawn at least one bounded child. Otherwise record `NO_INDEPENDENT_WORK`, `TOOL_UNAVAILABLE`, or `CRITICAL_PATH_ONLY`.
- Routing does not imply spawning. The lead agent is the single-agent topology.
- Model names are runtime mappings, not durable policy. Capability classes are durable.
- Security, authorization, production, destructive operations, data migrations, architecture, and incident response have mandatory capability floors.
- Delegation may reduce elapsed time or context size, but never transfers final accountability from the lead agent.
- Agents do not duplicate the same investigation or edit overlapping files without an explicit integration plan.

## Gate

Pass only when the selected route is justified, context is bounded, work is not duplicated, escalation triggers are active, and verification matches risk.
