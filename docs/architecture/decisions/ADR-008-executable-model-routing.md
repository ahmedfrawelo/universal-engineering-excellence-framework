# ADR-008: Executable Dynamic Model Routing

## Status

Accepted.

## Context

The routing tier previously expressed only a capability class while selectors retained the primary conversation's model. A hand-maintained model catalog would also drift from the models available to the signed-in Codex account.

## Decision

`config/model-routing-policy.json` owns T0-T4 capability classes and effort quantiles, the default `high` ceiling, explicit override rules, and one capacity fallback. It never owns an account model list, a translated effort-name table, or adaptive learning state.

UEEF reads the signed-in host's current model and effort metadata through Codex App Server `model/list`, selects from all eligible general models, and dispatches the work unit through a model-aware host tool with explicit model and effort overrides. Within the best matching capability class, a stable tier plus work-unit key distributes execution across every eligible model instead of permanently selecting one winner. Hidden models require a specialist purpose whose words match the host description. The App Server executable is resolved from the active Codex runtime before `PATH`, so a WindowsApps execution restriction is not misreported as missing account models. The original conversation remains accountable and must report the model and effort actually used; it does not claim that its model picker changed.

Routing is repeated at each materially different work unit. The host publishes the route before dispatch and publishes a replacement line before a changed route. Every T0-T4 work unit must dispatch before other task tooling, then publish the actual full model and effort verified by the host or App Server; a requested pair or model prose is insufficient. Routed turns preserve user language by default and accept a BCP-47 language tag such as Arabic `ar`. Automatic routing ignores the current picker. An explicit current-model constraint is fail-closed and can be removed only by a separate explicit user authorization. The same rule applies to efforts above `high`.

On `Selected model is at capacity`, capture the capacity result in the task evidence, attempt one already-declared fallback, and do not rotate accounts, browser profiles, cookies, credentials, or user identity state. The next route is discovered fresh; no learned availability score is retained.

## Consequences

- Routes are observable execution decisions, not capability-only recommendations.
- Every model is discovered at runtime from the signed-in host rather than hard-coded from a screenshot or stale catalog.
- Every discovered entry is represented in route coverage; all eligible general models participate in deterministic work-unit distribution, while hidden host-specialist models require a matching specialist purpose.
- Capability selection uses host metadata and descriptions, not the count of reasoning options.
- Default tasks do not exceed `high`; a higher effort requires an explicit user instruction.
- The primary picker is used only when the user explicitly requests it.
- Effort display names come only from live host metadata; otherwise the exact technical identifier is displayed unchanged.
- If no eligible model is available, the task remains active with a truthful provider-capacity report.
