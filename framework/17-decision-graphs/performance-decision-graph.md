# Performance Decision Graph

Category: decision graphs
UEEF version: 1.0.0
Applies to: AI coding assistants, maintainers, reviewers, and technical leads.

## Purpose

Performance Decision Graph defines enforceable engineering behavior for repeatable delivery. Use this module before editing code, while reviewing proposed changes, and before declaring a task complete. The goal is to convert expert judgment into checks that an AI assistant can execute consistently across stacks.

## When To Load

Load this module when the task touches decision graphs concerns, when the project scan finds related files, or when the user's request creates risk in this area. If the stack is unknown, inspect the repository first and then decide whether this module applies.

## Operating Principles

- Treat Performance Decision Graph as a decision aid, not decoration.
- Prefer current repository evidence over assumptions.
- Make tradeoffs explicit when constraints conflict.
- Use the strongest verification available for the risk level.

## Required Behavior

- MUST inspect existing conventions before creating new patterns.
- MUST avoid duplicated logic, duplicated UI, and unowned standalone files.
- MUST preserve clean architecture, security defaults, and performance budgets.
- MUST record limitations when verification depends on external services.

## Inspection Protocol

1. Identify the active project root, package manager, runtime, framework, and deployment target.
2. Read the nearest existing implementation before proposing a new pattern.
3. Locate tests, build scripts, lint rules, formatting rules, and existing architectural boundaries.
4. Detect whether relevant MCP servers, skills, browser tools, database tools, or cloud tools are available.
5. State what will change, what will not be touched, and what evidence will prove the work.

## Quality Gates

- VERIFY the project was inspected before edits.
- VERIFY the chosen approach aligns with existing architecture.
- VERIFY lint, typecheck, build, tests, security checks, or credible alternatives were considered.
- VERIFY the final answer names evidence rather than relying on intent.

## AI Assistant Contract

The assistant must not invent standalone artifacts when a project convention already exists. It must preserve user work, avoid unrelated rewrites, and prefer the smallest coherent change that satisfies the full requested end state. If verification cannot run locally, the assistant must explain the exact missing command, dependency, permission, or external service.

## Failure Modes

- Skipping repository inspection and applying generic advice.
- Treating a green build as proof when the relevant behavior was not exercised.
- Duplicating UI, domain logic, schemas, validators, or deployment scripts.
- Hiding security, performance, or maintainability tradeoffs behind vague language.
- Declaring completion from intent rather than current evidence.

## Review Questions

- Does this change improve the requested outcome without broadening scope unnecessarily?
- Are architectural boundaries still clear after the change?
- Would a new engineer understand why this design exists?
- Is the verification strong enough for the risk level?
- Are remaining limitations explicit and actionable?

## Output Requirements

Final responses should include the files changed, verification performed, residual risk, and the next manual step only when a manual step is genuinely required.

## Cross References

- Master index: ../MASTER_INDEX.md
- Golden rules: ../99-golden-rules/engineering-golden-rules.md
- Quality gates: ../16-review-system/quality-gates.md
