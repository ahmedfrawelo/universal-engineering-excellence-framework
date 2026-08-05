# Technical Plan Translation

## Purpose

The technical plan translates the specification into implementation choices without losing traceability.

## Required Plan Content

- Requirement mapping: which plan decisions satisfy which requirements.
- Architecture and ownership boundaries.
- Data model and persistence changes.
- API, event, realtime, or integration contracts.
- UI/component/state changes where relevant.
- Test strategy and evidence order.
- Security, authorization, privacy, and abuse considerations.
- Performance, caching, pagination, rendering, concurrency, and operational risks.
- Migration, rollout, rollback, and compatibility notes.

## Rules

- Every major technical choice must cite the requirement or constraint that justifies it.
- Complexity must be explained. New abstraction, dependency, service, package, or data model choices require a reason.
- Prefer existing repository patterns unless the specification requires changing them.
- If implementation requires a different approach than the plan, update the plan before continuing.
