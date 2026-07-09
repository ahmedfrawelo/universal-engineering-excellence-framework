# master loader

Version: 1.0  
Pack: 01-core  
Status: Stable  
Applies To: core

## Purpose

master loader defines practical engineering behavior that AI coding assistants and engineering teams can apply during real project work. It converts senior engineering judgment into repeatable operating rules.

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

Before every non-trivial engineering task, UEEF requires a preflight check. The assistant must not start implementation until it can produce UEEF Active: YES with evidence from repository files, a global loader, or the status script.

Required core load order:

- ramework/01-core/00-core-system.md
- ramework/01-core/01-master-loader.md
- ramework/01-core/02-master-index.md
- ramework/01-core/10-runtime-activation-proof.md
- ramework/01-core/11-ueef-status-check.md
- ramework/01-core/12-ueef-required-preflight.md
- ramework/03-runtime/00-runtime-sequence.md
- ramework/27-quality-gates/16-ueef-activation-gate.md

The assistant must select relevant modules, check MCPs/tools/skills, apply UI UX Pro Max for UI work, plan quality gates, and include UEEF verification in the final response.
## Global Loader Instruction
# UEEF Global Loader

Before every engineering task:
1. Load UEEF Core System: `framework/01-core/00-core-system.md`.
2. Load UEEF Master Loader: `framework/01-core/01-master-loader.md`.
3. Load UEEF Master Index: `framework/01-core/02-master-index.md` and `framework/MASTER_INDEX.md`.
4. Run the UEEF Runtime Check before implementation.
5. Select exact relevant UEEF modules for the request.
6. Check MCPs, tools, connectors, local scripts, and installed skills.
7. Apply UI UX Pro Max whenever UI, UX, frontend, design, layout, accessibility, or visual polish is involved.
8. Produce a plan before editing non-trivial work.
9. Apply UEEF Quality Gates before the final answer.
10. Include UEEF verification evidence in the final response.

If the runtime check cannot produce `UEEF Active: YES`, report:

```text
UEEF Active: NO
Reason:
Required action:
```

When status is `BLOCKED`, do not edit project files.
