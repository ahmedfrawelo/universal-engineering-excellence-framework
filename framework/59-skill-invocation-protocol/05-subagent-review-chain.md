# Subagent Review Chain

## Purpose

Subagents improve throughput only when they have bounded ownership and independent verification. They should not be spawned for appearance or vague exploration.

## Dispatch Rules

- Give each subagent a concrete task, file or module ownership, required context, and expected evidence.
- Do not make a subagent rediscover the whole project when the lead already has the relevant plan.
- Keep immediate blockers and final integration with the lead.
- Do not duplicate write scopes across subagents.
- Require final evidence from every child: files changed or inspected, checks run, issues found, and residual risk.

## Review Order

1. Spec compliance: does the result satisfy the requested task and avoid extras?
2. Code quality: does it fit architecture, security, performance, tests, and maintainability?
3. Integration: does it work with other local changes?

## Failure Handling

- If spec compliance fails, fix the spec gap before code-quality approval.
- If the child reports uncertainty, inspect the owning files locally before merging.
- If the child changed unrelated files, isolate and reject those changes unless required by the task.
