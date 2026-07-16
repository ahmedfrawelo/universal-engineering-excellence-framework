# Spec-Driven Development System

## Purpose

This module requires the assistant to convert broad, ambiguous, or durable work into explicit specification artifacts before implementation. The specification is the source of truth; code, tests, plans, and tasks must trace back to it.

## Core Rules

- Use spec-driven development when the request affects multiple files, user-facing behavior, public APIs, data models, migrations, infrastructure, security, agent behavior, or product workflow.
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
- convergence notes: mismatches found between spec, plan, tasks, code, and tests.

## Quality Gate

Passes when implementation, tests, and final claims trace to a current specification, and no material ambiguity, contradiction, or uncovered requirement remains hidden.
