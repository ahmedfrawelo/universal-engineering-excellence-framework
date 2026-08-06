# ADR-010: Token Economy and Managed Route Execution

## Status

Accepted.

## Date

2026-08-06

## Context

ADR-008 made dynamic host-catalog routing executable, but it did not define a mechanical context budget, worker limit, execution-spec floor, or separation between internal workers and user-visible Codex tasks. Routing smoke tests could also leave visible tasks, and strict command matching produced false positives for quoted punctuation, documentation patches, and application-supplied ambient browser metadata.

The affected boundaries are public: `config/model-routing-policy.json`, managed hook policy, route artifacts, App Server dispatch receipts, spec workflows, repository intelligence, and runtime status.

## Decision

Extend the dynamic route with a digest-bound token-economy contract and minimum execution spec.

- T0/T1 default to minimal single-agent execution.
- T2 defaults to one bounded sidecar.
- T3 permits at most three workers for disjoint useful work.
- T4 permits at most four workers and retains risk-matched independent verification.
- The lead owns planning, integration, final verification, and completion.
- Workers receive bounded owners, non-goals, evidence requirements, and a default output cap of 12 bullets or 250 words.
- T2+ route creation requires acceptance criteria, owner paths, and non-goals, then persists an execution-spec digest in the protected route artifact.
- App Server routed executions and smoke tests are ephemeral and may not create visible sidebar tasks.
- Visible task creation requires explicit authorization in the current prompt; internal Leader/Worker delegation does not imply it.

Harden command enforcement without weakening execution safety:

- recognize only strictly isolated `functions.exec` wrappers for the route recorder and direct dispatcher;
- parse shell control operators outside quoted arguments, allowing punctuation in route metadata while denying compound commands;
- treat text inside a patch as source or documentation rather than as an executed shell command, while keeping actual file-removal patch markers authorization-gated;
- exclude `in-app-browser-context` ambient metadata from task classification because it is host state, not user intent;
- require host-derived actual model and effort receipts before completion evidence.

Repository Graph presentation removes repeated summary nodes and disambiguates owner labels, but the graph remains generated evidence rather than a source owner.

## Consequences

- Token reduction becomes an enforceable constraint instead of an informal suggestion.
- Strong models remain responsible for decisions and convergence while bounded workers can reduce context and latency.
- Smoke tests no longer pollute the user's task list.
- User-visible task creation and internal delegation have separate authorization semantics.
- Route metadata can contain normal prose punctuation without self-locking the hook.
- Documentation and policy maintenance no longer trigger unrelated frontend or destructive-operation gates from ambient or quoted text.
- Actual compound commands, protected-path writes, file removal, route mismatch, excess worker count, and unverified execution remain denied.
- The route artifact and execution receipt formats gain additional fields and must evolve with their validators and tests.

## Rollback

Revert this ADR and the associated policy, hook, dispatcher, spec workflow, repository adapter, status, and test changes as one unit. Do not retain the new route or execution-spec fields with older validators, and do not disable individual guards to recover from a mismatch.
