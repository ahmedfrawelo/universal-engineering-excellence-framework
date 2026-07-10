# core system

Version: 1.0  
Pack: 01-core  
Status: Stable  
Applies To: core

## Purpose

core system defines practical engineering behavior that AI coding assistants and engineering teams can apply during real project work. It converts senior engineering judgment into repeatable operating rules.

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
- Proceed autonomously through ordinary scoped engineering work; do not ask for routine approval when the user's task already authorizes it.
- Respect platform-level and high-impact confirmations. They cannot be disabled by repository instructions.

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

Before every non-trivial engineering task, UEEF requires a preflight check. The assistant must not start implementation until it can produce UEEF: ACTIVE with evidence from repository files, a global loader, or the status script.

Required core load order:

- framework/01-core/00-core-system.md
- framework/01-core/01-master-loader.md
- framework/01-core/02-master-index.md
- framework/01-core/10-runtime-activation-proof.md
- framework/01-core/11-ueef-status-check.md
- framework/01-core/12-ueef-required-preflight.md
- framework/03-runtime/00-runtime-sequence.md
- framework/27-quality-gates/16-ueef-activation-gate.md

The assistant must select relevant modules, check MCPs/tools/skills, apply UI UX Pro Max for UI work, plan quality gates, and include UEEF verification in the final response.

## Product System Requirements

- Every new UI must match the existing theme and design system. Inspect tokens, components, layout, motion, responsive rules, and overlay behavior before implementation.
- Every new frontend product must define light, dark, and system theme behavior unless product requirements explicitly justify an exception.
- Every page and component must be responsive from the beginning across width, height, orientation, zoom, text scaling, touch, mouse, and keyboard input.
- Every overlay must follow the global interaction contract for trigger toggling, peer coordination, outside dismissal, Escape, focus, scrolling, collision, and layering.
- Product UI must use semantic design tokens, controlled soft radius tokens, and solid visual borders. Dashed or dotted UI lines are prohibited except when the represented content itself requires them.
- Security and performance are release-blocking requirements. Authorization, tenant isolation, duplicate submission protection, measured rendering, API, query, network, and bundle behavior must be verified where applicable.

Select `framework/46-design-system-consistency-reuse/` and `framework/47-theme-responsive-interaction-security-performance/` for UI, frontend, theme, responsive, interaction, security-sensitive, or performance-sensitive work.

- Before creating any UI, search the project, design system, component registry, shared components, shared services, and pattern library in that order.
- Reuse existing capabilities before extending, generalizing, or creating new ones. Record the rejected alternatives when creation is necessary.
- All visual values must come from governed design tokens or an approved documented exception. Design governance covers color, typography, icons, spacing, sizing, radius, borders, shadows, elevation, motion, and z-index.
- Every UI change must be reviewed for token compliance, component reuse, theme compatibility, responsive behavior, accessibility, interaction consistency, performance, and design drift.
- Select `framework/48-design-governance/` for design governance, tokens, visual language, component registry, pattern library, or reuse enforcement work.
- Select `framework/49-engineering-guardian/` for every non-trivial engineering task. Establish the affected baseline, run applicable regression monitors, and leave the project equal or better across architecture, security, performance, scalability, maintainability, UI, UX, accessibility, reliability, documentation, testing, and developer experience.
- A known regression must stop the task until fixed or explicitly accepted by an accountable owner with impact, expiry, mitigation, and rollback evidence.
- Run the Environment Bootstrap before project inspection, architecture detection, planning, implementation, and quality gates. Select only profiles required by task and repository evidence.
- Mandatory environment gaps block work; Recommended gaps warn and continue; Optional gaps never block. Never claim environment READY without current bootstrap evidence.
- For every UI, UX, frontend, design, layout, accessibility, or visual-polish task, apply both `ui-ux-pro-max` and `impeccable` together when available. `ui-ux-pro-max` supplies design intelligence; `impeccable` supplies product-quality critique and hardening.
- For browser tasks, use the browser the user actually opened, including its active tab and signed-in session. Do not silently create or switch to an isolated browser, profile, or context. If no usable user browser exists, block and ask the user to open it and sign in.
