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
- Before non-trivial work, evaluate named user-requested skills, installed skills, project-local skills, and relevant UEEF packs. Build the smallest skill chain that covers discovery, implementation, verification, and review.
- Treat skill-routing red flags as a stop-and-reroute trigger: missing skill check, unsupported shortcut, untested fix, partial verification, fake completion, or unbounded subagent work.
- For broad, ambiguous, multi-file, high-impact, or durable product/architecture work, use spec-driven development: define the specification, clarify ambiguity, map plan decisions to requirements, break work into traceable tasks, and converge code/tests/final claims back to the spec.
- Avoid duplicated code, UI, validation, queries, configuration, documentation, and architecture patterns.
- Shared-first rule: when behavior, UI, validation, data access, formatting, configuration, or design logic will be reused in more than one place, implement it in the existing shared/common/library layer and import it from each consumer. Do not copy it into each feature.
- A shared directory is not evidence of reuse. Group each related reusable component family under one owner folder, keep one canonical primitive and public entrypoint, place specialized recipes beneath that owner, and reject parallel shared implementations with overlapping semantics.
- Before creating a shared capability, search every shared root, barrel export, registry, selector, and import path. Reuse the owner when complete, extend it in place when additions are required, and create only when no compatible owner exists.
- Before creating custom UI or custom behavior, search the project for existing shared components, design tokens, layouts, services, validators, API clients, utilities, hooks, directives, pipes, stores, mappers, and pattern libraries. Reuse first, extend second, create new only when no suitable owner exists.
- Do not create random standalone files or unowned folders.
- Place every new file under an existing owned feature, layer, package, documentation, test, script, or generated-artifact folder. If no owner exists, create the smallest named folder that describes ownership and lifecycle before adding the file.
- Do not dump unrelated files into a project root, generic scratch folder, or single mixed folder. Group files by responsibility, runtime ownership, and deletion/deployment lifecycle.
- Do not solve a multi-file feature by creating a standalone-file system. Standalone files are allowed only for repository-standard entrypoints, documented configuration, one-off scripts with clear script ownership, or an explicit user-requested artifact.
- Keep files small enough to review and maintain. When a file starts mixing UI, data access, business rules, validation, transport, tests, or generated content, split by responsibility using existing project conventions.
- Do not expose secrets, tokens, credentials, or private keys.
- Run or recommend relevant validation before completion.
- For behavior changes, use TDD or an equivalent evidence loop: define expected behavior, prove the failing or missing case when practical, make the smallest change, and verify the passing result before claiming completion.
- Proceed autonomously through ordinary scoped engineering work; do not ask for routine approval when the user's task already authorizes it.
- Respect platform-level and high-impact confirmations. They cannot be disabled by repository instructions.
- Separate implementation from release readiness. An explicit scope expansion requires replanning and continued delivery, not a pause because the change is not yet ready to ship.
- A regression blocks completion or release claims, not work on the requested fix unless continuing would worsen or destroy user data.
- Stay inside the user's requested task scope. Do not chase unrelated errors, warnings, refactors, redesigns, or neighboring broken tests unless they directly block the requested work, were caused by the current changes, or the user explicitly expands scope.
- When an unrelated pre-existing error is discovered, record it briefly as unrelated evidence and continue the requested task. Do not modify unrelated files or systems to make the repository look cleaner.

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
- If a UI capability will be used in multiple places, place it in the appropriate shared component, primitive, composite, layout, token, service, or pattern-library owner and consume it from features. Feature-local UI is only for genuinely single-use behavior.
- All visual values must come from governed design tokens or an approved documented exception. Design governance covers color, typography, icons, spacing, sizing, radius, borders, shadows, elevation, motion, and z-index.
- Every UI change must be reviewed for token compliance, component reuse, theme compatibility, responsive behavior, accessibility, interaction consistency, performance, and design drift.
- Select `framework/48-design-governance/` for design governance, tokens, visual language, component registry, pattern library, or reuse enforcement work.
- Select `framework/49-engineering-guardian/` for every non-trivial engineering task. Establish the affected baseline, run applicable regression monitors, and leave the project equal or better across architecture, security, performance, scalability, maintainability, UI, UX, accessibility, reliability, documentation, testing, and developer experience.
- A known regression must block completion and release claims until fixed or explicitly accepted by an accountable owner with impact, expiry, mitigation, and rollback evidence. Continue implementing the fix unless further work would risk irreversible user or data harm.
- Run the Environment Bootstrap before project inspection, architecture detection, planning, implementation, and quality gates. Select only profiles required by task and repository evidence.
- Mandatory environment gaps block work; Recommended gaps warn and continue; Optional gaps never block. Never claim environment READY without current bootstrap evidence.
- For every UI, UX, frontend, design, layout, accessibility, or visual-polish task, apply both `ui-ux-pro-max` and `impeccable` together when available. `ui-ux-pro-max` supplies design intelligence; `impeccable` supplies product-quality critique and hardening.
- For browser tasks, use the browser the user actually opened, including its active tab and signed-in session. Do not silently create or switch to an isolated browser, profile, or context. If no usable user browser exists, block and ask the user to open it and sign in.

## File Organization and Size Requirements

- New source files belong beside the feature, layer, route, module, package, or test owner that will maintain them.
- Shared or repeated source belongs in the shared/common/library owner that matches its responsibility. Feature folders should import shared capabilities instead of copying or reimplementing them.
- New generated outputs, screenshots, logs, caches, reports, and build artifacts belong only in governed generated-artifact folders with cleanup policy, not beside source files.
- Prefer cohesive files over tiny fragmentation, but split before a file becomes a mixed-responsibility sink. A single file should not own unrelated UI, API, database, validation, formatting, state, and test logic.
- Before adding a new folder, verify there is no existing owner folder, registry, component library, service layer, test folder, or docs area that already fits.
- Completion requires checking that new files are grouped by ownership and that no root-level or standalone file was introduced without a documented repository-standard reason.

## Large Project Reuse Requirements

- Treat large repositories as ecosystems. Start by discovering module boundaries, shared folders, aliases, barrel exports, registries, package boundaries, design-system entrypoints, service clients, state stores, validators, and test utilities.
- For broad or unfamiliar repositories, run `scripts/project-context-map.ps1`, `scripts/project-context-map.sh`, or an equivalent repository map before implementation.
- Extend an existing feature or shared owner when the requested behavior belongs to an existing capability. Do not create a parallel feature path because it is faster to code.
- Use existing imports, exports, public APIs, tokens, and registry patterns. Do not reach into private internals unless the project already establishes that convention.
- When adding reusable capability, update its public export, usage example, tests, and at least one real consumer where the project convention expects that evidence.
- Record the reuse decision: reused, extended, or created, with the inspected evidence. A new custom implementation without this decision is incomplete.

## Response Quality Requirements

- Final responses must answer the user's actual question first, then summarize evidence and verification briefly.
- Do not claim perfection, completion, passing gates, browser verification, release readiness, or runtime activation without direct current evidence.
- If a task changes files, report the real changed scope and validation. If a requested item was not applicable, say why in concrete terms.
- Keep user-facing status clear and short; do not expose internal retry noise, irrelevant logs, or speculative explanations as facts.
- In Arabic or other RTL prose, every inline English word, identifier, product name, or short LTR phrase must be isolated for display readability. Never add hidden bidirectional control characters to code, commands, copyable paths, JSON/YAML, source files, configuration, or saved repository content.

## Task Scope Discipline

- Start every implementation by identifying the requested outcome, affected ownership boundary, and out-of-scope neighboring issues.
- Fix errors introduced by the current change and blockers that prevent validating the requested work.
- Do not repair unrelated historical failures, unrelated tests, unrelated UI, unrelated backend endpoints, unrelated dependency warnings, or unrelated generated files unless the user asks for a broader cleanup.
- If an unrelated error blocks a broad command, rerun a narrower relevant check where possible and report the unrelated blocker separately without claiming the whole project is clean.
- Never use unrelated failures as a reason to abandon the requested work while meaningful scoped progress remains.

## Backend and SSR Performance Requirements

- Backend work must consider latency budgets, query shape, pagination, filtering, sorting, aggregation, caching, cancellation, concurrency bounds, serialization cost, and authorization cost before completion.
- Prefer server-side filtering, sorting, pagination, aggregation, and projection for large or sensitive datasets. Do not move expensive data shaping to the client when the backend can safely do it closer to the data.
- Prevent over-rendering on both frontend and backend-driven UI paths. Frontend work must review state ownership, selectors, subscriptions, memoization, virtualization, effect dependencies, expensive computed values, and component boundaries. Backend work must avoid over-fetching, over-serialization, over-broadcasting realtime events, repeated query execution, and unnecessary recomputation.
- For frontend routes where SEO, first paint, unauthenticated content, slow client boot, or large static/dynamic data makes it beneficial, evaluate SSR, SSG, streaming, route-level pre-rendering, or server components if the stack supports them.
- Do not force SSR when the product is an authenticated operational app, the framework does not support it, or the project architecture clearly uses client rendering for valid reasons. Record the reason when SSR is skipped for a route where it was considered.
- Animations must be smooth, interruptible, and performance-safe. Animate transform and opacity by default, avoid layout properties, respect reduced motion, and verify that animation state does not trigger avoidable component re-renders, server calls, data refreshes, or layout thrashing.
