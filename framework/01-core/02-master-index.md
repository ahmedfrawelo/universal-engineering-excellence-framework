# master index redirect

Version: 1.0  
Pack: 01-core  
Status: Stable  
Applies To: core

## Canonical Index

The complete generated framework index is [`../MASTER_INDEX.md`](../MASTER_INDEX.md). This compatibility module remains because runtime preflight expects a core-level index path; it is not a second catalog.

## When To Use This Module

Use this module when the task touches core concerns, when repository inspection finds related files, or when a design decision could affect maintainability, security, performance, scalability, user experience, or production readiness.

## Core Principles

- Prefer current repository evidence over assumptions.
- Preserve established architecture unless the requested outcome requires a safe improvement.
- Choose simple, explicit designs before clever abstractions.
- Treat security, performance, accessibility, and operability as default requirements.
- Make tradeoffs visible when constraints conflict.

## Mandatory Rules

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

## Runtime Activation Requirement

Before every non-trivial engineering task, UEEF requires a preflight check. The assistant must not start implementation until it can produce `UEEF: ACTIVE` with evidence from repository files, the global loader, or the status script.

## Activation Modules

- `framework/01-core/10-runtime-activation-proof.md`
- `framework/01-core/11-ueef-status-check.md`
- `framework/01-core/12-ueef-required-preflight.md`
- `framework/03-runtime/00-runtime-sequence.md`
- `framework/27-quality-gates/16-ueef-activation-gate.md`

## Runtime Selection Rule

Use the canonical index to select exact modules for the task before implementation. UI, UX, frontend, design, accessibility, and visual-polish tasks must include both `ui-ux-pro-max` and `impeccable` status plus the UI, UX, accessibility, frontend, performance, and activation gates.
