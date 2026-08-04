# Agent and Model Orchestration System

## Purpose

Route every task to the smallest capable model class and agent topology while preserving engineering quality, security, and truthful verification.

## Mandatory Runtime Sequence

1. Classify complexity and risk before substantial work.
2. Check whether delegation can run independently and save more than it costs.
3. Select the minimum model capability and supported effort that satisfy the current work unit and risk floor.
4. Keep the critical path with the lead agent; delegate bounded, non-overlapping side work.
5. Give each child a minimal context packet, explicit ownership, deliverable, and stop condition.
6. Re-route before a materially different work unit; escalate or reduce capability after ambiguity, failed verification, expanding scope, reduced complexity, or discovered risk.
7. Close agents when their result is integrated.
8. Select a proportional fresh-context review mode before consequential completion.
9. Verify the combined result at the level required by the task, not by the model used.

## Invariants

- Every task passes the router, including conversational and trivial work.
- `medium` is the economical default, not a hard ceiling. Resolve every route through `config/model-routing-policy.json` and execute the task in the emitted named model and reasoning level; T3/T4 deliberately request higher reasoning.
- Every non-trivial task executes the route selector or records an equivalent classification before substantial work.
- T1 code changes default to a single lead agent. Spawn a bounded child only when an independent sidecar materially improves the result or latency; T2–T4 use the same benefit test, with T4 retaining independent verification.
- Before the first project command or edit, publish one Visible pre-command route line: `Agent route: <tier> | Agent: spawned <id or nickname>` or `Agent route: <tier> | Agent: not spawned - <reason>`.
- `NO_INDEPENDENT_WORK` is valid for a narrow code-changing T1 task. `TOOL_UNAVAILABLE` remains a valid capability reason; `CRITICAL_PATH_ONLY` is valid when delegation would not improve the requested outcome.
- A final UEEF pass claim is invalid when the route line is missing, or when a route that actually spawned a child lacks that child’s bounded-result evidence. A single-agent T1 route with `NO_INDEPENDENT_WORK` needs no child-agent evidence.
- Routing does not imply spawning. The lead agent is the single-agent topology.
- The versioned model-routing policy owns capability classes, effort quantiles, execution mode, the `high` ceiling, and one capacity fallback. It never owns concrete Codex names or translated effort labels. The live host catalog supplies those values and the host-agent creation result verifies availability; the original conversation must not pretend its own dropdown changed.
- Before each routed work unit, show the selected live model and host-provided effort label. If the model or effort changes, publish the changed route before dispatch. Do not silently retain the highest route for simpler work.
- On `Selected model is at capacity`, attempt only the route's declared fallback once. Do not rotate accounts, cookies, profiles, or credentials; if that fallback is unavailable, keep the task active and report provider capacity.
- Security, authorization, production, destructive operations, data migrations, architecture, and incident response have mandatory capability floors.
- Delegation may reduce elapsed time or context size, but never transfers final accountability from the lead agent.
- Agents do not duplicate the same investigation or edit overlapping files without an explicit integration plan.
- T3 recommends a fresh-context review for shared architecture, broad refactors, public contracts, and commitment boundaries. T4 requires fresh-context review evidence when an eligible review lane is available; a host capability gap is recorded, never disguised as independent review.
- A reviewer verdict is bound to the reviewed diff identity. Any later mutation invalidates it and requires a new review.

## Gate

Pass only when the selected route is justified, context is bounded, work is not duplicated, escalation triggers are active, and verification matches risk.
