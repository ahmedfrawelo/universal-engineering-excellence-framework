# task lifecycle

Version: 1.0  
Pack: 01-core  
Status: Stable  
Applies To: core

## Purpose

task lifecycle defines practical engineering behavior that AI coding assistants and engineering teams can apply during real project work. It converts senior engineering judgment into repeatable operating rules.

## When To Use This Module

Use this module when the task touches core concerns, when repository inspection finds related files, or when a design decision could affect maintainability, security, performance, scalability, user experience, or production readiness.

## Core Principles

- Prefer current repository evidence over assumptions.
- Preserve established architecture unless the requested outcome requires a safe improvement.
- Choose simple, explicit designs before clever abstractions.
- Treat security, performance, accessibility, and operability as default requirements.
- Make tradeoffs visible when constraints conflict.

## Mandatory Rules

### Goal State Machine

- `ACTIVE -> COMPLETE` only when the requested outcome is satisfied, no required work remains, applicable gates pass or are explicitly accepted, and verification is recorded.
- `ACTIVE -> BLOCKED` only when the blocker is external or user-only, no meaningful local work remains, and an external state change is required.
- `ACTIVE -> final response` is forbidden unless the user explicitly requested status-only reporting. Active work uses commentary and continues execution.
- Compile/test failures, incomplete implementation, regressions, and repeated unsuccessful patches keep the goal `ACTIVE`.
- A thread-scoped browser-control failure also keeps the goal `ACTIVE`; it is not an external blocker when trusted same-tab evidence can be handed off from a coordinator.
- `COMPLETE` is invalid when any required acceptance criterion, plan item, implementation, test, or verification remains.

- Inspect the project before editing.
- Detect existing conventions, reusable code, tools, MCPs, skills, and quality gates.
- Avoid duplicated code, UI, validation, queries, configuration, documentation, and architecture patterns.
- Do not create random standalone files or unowned folders.
- Do not expose secrets, tokens, credentials, or private keys.
- Run or recommend relevant validation before completion.

## Decision Guidance

1. Identify the smallest coherent change that satisfies the full requested end state.
2. Compare at least two implementation paths when risk is non-trivial.
3. Prefer the path that improves long-term clarity without expanding scope recklessly.
4. Document unavoidable technical debt with risk, impact, and follow-up.
5. Match verification strength to risk.

## Anti-Patterns

- Editing before inspection.
- Treating a green build as proof when the requested behavior was not checked.
- Adding dependencies for convenience alone.
- Creating duplicate UI or duplicate domain logic.
- Hiding limitations behind vague final wording.

## Review Checklist

- The relevant files, scripts, and conventions were inspected.
- The change belongs in the selected location.
- Names communicate purpose and business meaning.
- Security and performance risks were considered.
- Verification evidence matches the scope of the change.

## Quality Gate

This module passes when the final implementation is understandable, maintainable, secure by default, reasonably performant, consistent with project architecture, and supported by honest verification evidence.

## Related Modules

- ../01-core/01-master-loader.md
- ../03-runtime/00-runtime-sequence.md
- ../27-quality-gates/00-quality-gate-system.md

## Success Criteria

- The assistant can explain why the selected approach fits the project.
- No unrelated user work is changed.
- No placeholders, empty guidance, or fake completion claims remain.
- Residual limitations are explicit and actionable.
