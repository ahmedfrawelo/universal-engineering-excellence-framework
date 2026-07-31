# Core System

Version: 1.1
Pack: 01-core  
Status: Stable  
Applies To: every non-trivial UEEF-governed task

## Purpose

The Core System is the executable policy boundary for activation, scope, routing, evidence, and completion. It coordinates specialized packs without replacing their domain rules.

## Required Decisions

1. Identify the requested outcome, ownership boundary, risk, and explicit exclusions.
2. Prove whether the current path is a validated source checkout or an active managed runtime.
3. Load only the modules, skills, tools, and gates justified by inspected evidence.
4. Select the smallest coherent route and verification strength that can prove the outcome.
5. Keep implementation active until acceptance evidence is complete or a genuine external blocker remains.

## Non-Negotiable Rules

- Current repository evidence overrides memory and generic assumptions.
- Proceed autonomously through ordinary scoped engineering work; ask only when a material user choice or new authority is required.
- Scope wins over broad audits, upgrades, delegation, or ceremony unless the user explicitly expands it.
- Activation, capability, browser, validation, and completion claims require direct current evidence.
- Existing owners, shared mechanisms, design systems, and conventions are reused before new parallel paths are created.
- Shared-first rule: place behavior used by multiple consumers in the existing shared/common/library owner and import it from each consumer.
- Before creating custom UI or custom behavior, search the project's components, tokens, services, validators, clients, stores, utilities, and pattern registries.
- Security, data integrity, accessibility, performance, recovery, and operability are selected in proportion to actual risk.
- User-owned changes and secrets remain untouched unless the requested task specifically authorizes them.

## Required Evidence

- Route rationale: intent, tier, spawn decision, and browser decision.
- Activation or source-validation status from the supported status contract.
- A requirements-to-change-to-verification trace for the requested outcome.
- Exact failures, skipped checks, residual risks, and owners; warnings never become implicit passes.

## Failure Conditions

- Work begins from an unvalidated or falsely claimed runtime state.
- Routing expands beyond the user's outcome without direct necessity or authority.
- A required gate fails, evidence is fabricated, or incomplete work is reported as complete.
- A broad rule contradicts a narrower applicable module or repository-local instruction.

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

The assistant must select relevant modules, check MCPs/tools/skills, choose the proportionate frontend mode for UI work, plan quality gates, and include UEEF verification in the final response.

## Product System Requirements

- Every new UI must match the existing theme and design system. Inspect tokens, components, layout, motion, responsive rules, and overlay behavior before implementation.
- Every new frontend product must define light, dark, and system theme behavior unless product requirements explicitly justify an exception.
- Every page and component must be responsive from the beginning across width, height, orientation, zoom, text scaling, touch, mouse, and keyboard input.
- Every overlay must follow the global interaction contract for trigger toggling, peer coordination, outside dismissal, Escape, focus, scrolling, collision, and layering.
- Product UI must use semantic design tokens, controlled soft radius tokens, and solid visual borders. Dashed or dotted UI lines are prohibited except when the represented content itself requires them.
- Security and performance are release-blocking requirements. Authorization, tenant isolation, duplicate submission protection, measured rendering, API, query, network, and bundle behavior must be verified where applicable.

Select `framework/10-frontend/01-frontend-task-modes.md` for UI and frontend work. Add relevant modules from `framework/46-design-system-consistency-reuse/` and `framework/47-theme-responsive-interaction-security-performance/` only when reuse, theme, responsive, interaction, security, or performance contracts are touched.

- Before creating any UI, search the project, design system, component registry, shared components, shared services, and pattern library in that order.
- Reuse existing capabilities before extending, generalizing, or creating new ones. Record the rejected alternatives when creation is necessary.
- If a UI capability will be used in multiple places, place it in the appropriate shared component, primitive, composite, layout, token, service, or pattern-library owner and consume it from features. Feature-local UI is only for genuinely single-use behavior.
- All visual values must come from governed design tokens or an approved documented exception. Design governance covers color, typography, icons, spacing, sizing, radius, borders, shadows, elevation, motion, and z-index.
- Review each UI change only against the contracts it touches. New or broad surfaces require wider token, reuse, theme, responsive, accessibility, interaction, performance, and drift review; bounded existing-owner changes use focused checks.
- Select `framework/48-design-governance/` for design governance, tokens, visual language, component registry, pattern library, or reuse enforcement work.
- For T2+ or elevated-risk work, select the applicable `framework/49-engineering-guardian/` modules. T0/T1 work uses a focused relevant check unless risk, scope, or the user request requires more; when selected, establish the affected baseline, run applicable regression monitors, and leave the project equal or better across the affected quality dimensions.
- A known regression must block completion and release claims until fixed or explicitly accepted by an accountable owner with impact, expiry, mitigation, and rollback evidence. Continue implementing the fix unless further work would risk irreversible user or data harm.
- Run the Environment Bootstrap before project inspection, architecture detection, planning, implementation, and quality gates. Select only profiles required by task and repository evidence.
- Mandatory environment gaps block work; Recommended gaps warn and continue; Optional gaps never block. Never claim environment READY without current bootstrap evidence.
- For UI work, select exactly one frontend mode: `Quick`, `Build`, or `Audit`. Use `typeui-fundamentals` for relevant fundamentals, `frontend-design` for production construction, `impeccable` for critique/redesign/polish, and `ui-ux-pro-max` for explicit product or style intelligence. Do not stack skills solely because the task mentions frontend or design, and do not block focused work on a missing optional skill.
- For browser tasks, use the browser the user actually opened, including its active tab and signed-in session. Do not silently create or switch to an isolated browser, profile, or context. If no usable user browser exists, block and ask the user to open it and sign in.

## File Organization and Size Requirements

- Place every new file under an existing owned feature, layer, package, documentation, test, script, or generated-artifact folder.
- Do not solve a multi-file feature by creating a standalone-file system.
- Keep files small enough to review and maintain; split mixed responsibilities using existing project conventions.
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

- Stay inside the user's requested task scope.
- Start every implementation by identifying the requested outcome, affected ownership boundary, and out-of-scope neighboring issues.
- Fix errors introduced by the current change and blockers that prevent validating the requested work.
- Do not repair unrelated historical failures, unrelated tests, unrelated UI, unrelated backend endpoints, unrelated dependency warnings, or unrelated generated files unless the user asks for a broader cleanup.
- If an unrelated error blocks a broad command, rerun a narrower relevant check where possible and report the unrelated blocker separately without claiming the whole project is clean.
- Never use unrelated failures as a reason to abandon the requested work while meaningful scoped progress remains.
- **Scope wins:** when scope conflicts with continuation, delegation, autonomy, audits, or modernization, follow the user's requested task. Expand only for an explicit request or a direct verification blocker.

## Ask/Do and Route Visibility

- In Ask mode, resolve only material ambiguity: ask one concise question or disclose the smallest reversible assumption.
- In Do mode, execute the clear requested outcome and direct verification only.
- Before non-trivial execution, emit: `Intent: <requested outcome> | Tier: <T0-T4> | Spawn: <no/yes and reason> | Browser: <no/yes and reason>`.

## Backend and SSR Performance Requirements

- Backend work must consider latency budgets, query shape, pagination, filtering, sorting, aggregation, caching, cancellation, concurrency bounds, serialization cost, and authorization cost before completion.
- Prefer server-side filtering, sorting, pagination, aggregation, and projection for large or sensitive datasets. Do not move expensive data shaping to the client when the backend can safely do it closer to the data.
- Prevent over-rendering on both frontend and backend-driven UI paths. Frontend work must review state ownership, selectors, subscriptions, memoization, virtualization, effect dependencies, expensive computed values, and component boundaries. Backend work must avoid over-fetching, over-serialization, over-broadcasting realtime events, repeated query execution, and unnecessary recomputation.
- For frontend routes where SEO, first paint, unauthenticated content, slow client boot, or large static/dynamic data makes it beneficial, evaluate SSR, SSG, streaming, route-level pre-rendering, or server components if the stack supports them.
- Do not force SSR when the product is an authenticated operational app, the framework does not support it, or the project architecture clearly uses client rendering for valid reasons. Record the reason when SSR is skipped for a route where it was considered.
- Animations must be smooth, interruptible, and performance-safe. Animate transform and opacity by default, avoid layout properties, respect reduced motion, and verify that animation state does not trigger avoidable component re-renders, server calls, data refreshes, or layout thrashing.
- Mutable remote state must reconcile without page reload when freshness is required. Patch or invalidate the smallest authorized scope, preserve user context, and verify ordering, deduplication, reconnect, security, and burst behavior.
- Every non-trivial route, feature, component, asset, integration, worker, and optional service requires an evidence-based eager, lazy, preload, prefetch, stream, or defer decision. Do not force lazy loading where it worsens the critical path or creates waterfalls.
- Inventory runtime and dependency currency only for explicit modernization/dependency work or when a T2+ task needs it as direct evidence. Do not turn T0/T1 work into an autonomous upgrade or inventory.
- Broad refactoring of legacy projects requires a repository map, behavior baseline, characterization tests, hidden-reachability checks before dead-code deletion, reversible slices, migration sequencing, performance comparison, rollout, and rollback.
