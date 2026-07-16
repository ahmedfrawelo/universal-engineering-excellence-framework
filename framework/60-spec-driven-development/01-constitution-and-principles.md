# Constitution and Principles

## Purpose

Project principles constrain every specification, plan, and implementation. They prevent a generated feature from drifting away from architecture, security, testing, and user experience standards.

## Rules

- Identify the project's governing principles before writing the plan: architecture boundaries, test policy, security posture, performance budget, UI system, deployment rules, and data ownership.
- If no explicit constitution exists, derive a short working constitution from repository evidence and UEEF defaults.
- Treat principles as gates, not decoration. A plan that violates them must document the exception, impact, owner, mitigation, and expiry.
- Keep the constitution stable during a feature unless the task explicitly includes changing project principles.
- When the constitution changes, record why existing specs, plans, tests, and generated work remain valid or need migration.

## Minimum Principle Set

- Architecture: ownership, module boundaries, reuse, and dependency direction.
- Testing: required test levels and evidence order.
- Security: auth, authorization, data exposure, secrets, and tenant boundaries.
- Performance: latency, data volume, rendering, query, and realtime limits.
- UX: accessibility, responsive behavior, loading states, and design-system reuse.
- Operations: logging, observability, rollout, rollback, and support expectations.
