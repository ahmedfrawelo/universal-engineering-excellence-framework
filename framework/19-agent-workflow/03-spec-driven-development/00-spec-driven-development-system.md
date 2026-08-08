# Spec-Driven Development System

## Purpose

This module requires the assistant to convert broad, ambiguous, or durable work into explicit specification artifacts before implementation. The specification is the source of truth; code, tests, plans, and tasks must trace back to it.

## Core Rules

- Use spec-driven development when the request affects multiple files, user-facing behavior, public APIs, data models, migrations, infrastructure, security, agent behavior, or product workflow.
- For T2+ work, capture an execution spec before broad inspection, delegation, or implementation. The spec can be lightweight, but it must be explicit enough to constrain token spend and worker scope.
- Separate what and why from how. The specification records user value, scope, behavior, constraints, exclusions, success criteria, and acceptance scenarios before technology decisions.
- Do not hide assumptions. Mark ambiguity, ask when necessary, or choose a documented conservative default only when the user has authorized autonomous execution.
- Convert the approved or inferred specification into a technical plan that records architecture, data, API, UI, test, performance, security, and operational decisions.
- Break the plan into tasks with dependencies, independent work items, validation commands, and ownership.
- Implement only tasks that trace to the specification or an explicitly approved scope change.
- When implementation reveals a requirement gap, update the specification or task list before continuing.

## Required Artifacts

For substantial work, produce or update the project-local equivalent of:

- specification: user stories, requirements, non-goals, acceptance criteria, risks, and success measures.
- plan: technical approach, dependencies, architecture, data contracts, security/performance considerations, and validation strategy.
- tasks: ordered executable tasks, parallel-safe groups, test gates, and done criteria.
- task graph and execution state: machine-readable dependencies, ownership, dynamic wave policy, resume state, and evidence-backed transitions when the work uses the executable workflow.
- convergence notes: mismatches found between spec, plan, tasks, code, and tests.
- token and worker budget: selected model tier, allowed delegation topology, maximum worker count, output cap, and evidence storage rule.

## Phase Mapping

Use these phases when translating Spec Kit-style requests into UEEF-owned work:

1. Constitution: define or confirm governing project principles.
2. Specify: capture requirements, user value, non-goals, and acceptance criteria without implementation detail.
3. Clarify: resolve open questions or record explicit assumptions before dependent planning.
4. Plan: choose architecture, technology, data/API contracts, risks, and validation strategy.
5. Tasks: create ordered work with dependencies, evidence, and safe parallelization boundaries.
6. Checklist and analyze: check completeness, contradiction, ambiguity, traceability, and acceptance coverage before implementation.
7. Implement: execute only tasks that trace to the current spec or approved goal update.
8. Converge: compare spec, plan, tasks, implementation, tests, and final claims; append remaining work instead of hiding drift.
9. Task-to-issue export: optional planning output only; creating external issues requires explicit user authorization.

Spec Kit slash commands or skills are external interface names. Inside UEEF, phases are enforced through local artifacts, validators, evidence, and completion audits.

## Token Economy Coupling

The specification owns the budget. A technical plan must not expand model capability, fan-out, source scanning, or evidence volume beyond the recorded budget unless the lead updates the spec or records a goal update route.

For T2+ work, record:

- token budget mode: `minimal`, `bounded`, or `expanded`;
- delegation policy and maximum worker count;
- context sources permitted before implementation;
- worker output cap;
- evidence that must be artifact-backed rather than pasted into chat.

For managed Codex execution, `record-ueef-route.mjs` creates this lightweight execution spec automatically for T2+ and binds it to the route state. Durable `.ueef/specs/<id>` artifacts remain required when the task's ambiguity, reuse, or lifecycle needs the full workflow; the automatic route spec is the minimum mechanical floor, not a replacement for a substantial product specification.

## Quality Gate

Passes when implementation, tests, and final claims trace to a current specification, and no material ambiguity, contradiction, or uncovered requirement remains hidden.
