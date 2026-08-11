# Agent and Model Orchestration System

## Purpose

Route every task to the smallest capable model class and agent topology while preserving engineering quality, security, and truthful verification.

## Mandatory Runtime Sequence

1. Classify complexity and risk before substantial work.
2. Check whether delegation can run independently and save more than it costs.
3. Select the minimum model capability and supported effort that satisfy the current work unit and risk floor.
4. Publish the three execution decisions before substantial work: `Mode: REVIEW|IMPLEMENTATION`, `Spec: NONE|LIGHT|FULL_REQUIRED`, and `Team: NONE|AUTHORIZATION_REQUIRED|SPAWN`, each with its reason.
5. Keep the critical path with the lead agent; delegate bounded, non-overlapping side work.
6. Give each child a minimal context packet, explicit ownership, deliverable, and stop condition.
7. Re-route before a materially different work unit; escalate or reduce capability after ambiguity, failed verification, expanding scope, reduced complexity, or discovered risk.
8. Close agents when their result is integrated.
9. Select a proportional fresh-context review mode before consequential completion.
10. Verify the combined result at the level required by the task, not by the model used.

## Invariants

- Every task passes the router, including conversational and trivial work.
- `medium` is the economical default, not a hard ceiling. Resolve every route through `config/model-routing-policy.json` and execute the task in the emitted named model and reasoning level; T3/T4 deliberately request higher reasoning.
- Every task records route metadata before mutation or non-read execution. T0/T1 execute host-native in the current lead conversation: they do not duplicate the work through an App Server dispatch, require an actual-model receipt, or expose the eight-label completion block. T2+ dispatches the selected route and must disclose the actual model with the full technical model identifier and host-provided effort before execution. Do not abbreviate, translate, infer, or hallucinate model names. A picker label, screenshot, subagent prose self-report, or assistant self-identification is not T2+ execution evidence. If host dispatch evidence cannot prove the actual pair, report `Model used: UNVERIFIED` and keep T2+ completion unproven.
- Every non-trivial task executes the route selector or records an equivalent classification before substantial work.
- T1 code changes default to a single lead agent. Spawn a bounded child only when an independent sidecar materially improves the result or latency; T2–T4 use the same benefit test, with T4 retaining independent verification. Positive benefit is necessary but not sufficient: spawning also requires current authorization from the user, platform policy, or an applicable task instruction. Platform policy grants only `INDEPENDENT_VERIFIER`; it never grants implementation-worker authority. When benefit exists without authorization, publish `Team: AUTHORIZATION_REQUIRED` rather than silently remaining single-agent or pretending a team exists.
- Safe read-only intake may precede routing. Before the first mutation or non-read execution, publish the visible decision contract: `Mode: <REVIEW|IMPLEMENTATION> | Spec: <NONE|LIGHT|FULL_REQUIRED> - <reason> | Team: <NONE|AUTHORIZATION_REQUIRED|SPAWN>/<NONE|WORKERS|INDEPENDENT_VERIFIER> - <reason>`, followed by one Visible pre-command route line: `Agent route: <tier> | Agent: spawned <id or nickname>` or `Agent route: <tier> | Agent: not spawned - <reason>`.
- `NO_INDEPENDENT_WORK` is valid for a narrow code-changing T1 task. `TOOL_UNAVAILABLE` remains a valid capability reason; `CRITICAL_PATH_ONLY` is valid when delegation would not improve the requested outcome.
- A final UEEF pass claim is invalid when the route line is missing, or when a route that actually spawned a child lacks that child’s bounded-result evidence. A single-agent T1 route with `NO_INDEPENDENT_WORK` needs no child-agent evidence.
- Routing does not imply spawning. The lead agent is the single-agent topology.
- The versioned model-routing policy owns capability classes, effort quantiles, execution mode, the `high` ceiling, and one capacity fallback. It never owns concrete Codex names or translated effort labels. The live host catalog supplies those values and the host-agent creation result verifies availability; the original conversation must not pretend its own dropdown changed.
- Before each routed work unit, show the selected live model and host-provided effort label from verifiable host/catalog evidence. If the model or effort changes, publish the changed route before dispatch. Do not silently retain the highest route for simpler work, and do not substitute picker labels or guessed model names for execution evidence.
- On `Selected model is at capacity`, attempt only the route's declared fallback once. Do not rotate accounts, cookies, profiles, or credentials; if that fallback is unavailable, keep the task active and report provider capacity.
- Security, authorization, production, destructive operations, data migrations, architecture, and incident response have mandatory capability floors.
- Delegation may reduce elapsed time or context size, but never transfers final accountability from the lead agent.
- Agents do not duplicate the same investigation or edit overlapping files without an explicit integration plan.
- T3 recommends a fresh-context review for shared architecture, broad refactors, public contracts, and commitment boundaries. T4 requires fresh-context review evidence when an eligible review lane is available; the lead runs the selected review lane automatically before completion rather than asking the user to request it. A host capability gap is recorded and strengthened with direct evidence, never disguised as independent review.
- A reviewer verdict is bound to the reviewed diff identity. Any later mutation invalidates it and requires a new review.

## Gate

Pass only when the selected route is justified, context is bounded, work is not duplicated, escalation triggers are active, and verification matches risk.
