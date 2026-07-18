# Master Loader

Version: 1.0
Pack: 01-core
Status: Stable
Applies To: selective module loading

## Purpose

The Master Loader chooses the minimum useful UEEF module set for the current task. It is a selector, not a command to load every UEEF file.

## Always Loaded Before This Selector

- `framework/01-core/00-boot-loader.md`
- `framework/01-core/00-core-system.md`

## Selection Policy

- Select by task type, risk, stack, and files touched.
- Load module paths first; load full module content only when needed.
- Never load all UEEF files for normal coding tasks.
- Load the full framework only for UEEF audits, UEEF updates, UEEF rebuilds, or explicit full-framework requests.
- Keep runtime and final verification compact.
- Select `framework/01-core/13-autonomy-and-confirmation-policy.md` for any task where execution autonomy, confirmation behavior, or platform approvals matter.
- Select `framework/01-core/14-delivery-continuation-policy.md` when scope expands, a migration/rebuild is requested, or release readiness could be confused with implementation progress.
- Route every task through `framework/58-agent-model-orchestration/00-agent-model-orchestration-system.md` and `01-task-complexity-classifier.md`. Select the remaining pack modules when delegation, model override, parallel agents, token economy, escalation, or independent verification applies.
- Select `framework/59-skill-invocation-protocol/` for named skill requests, skill routing, workflow protocols, Superpowers-inspired workflow work, TDD/evidence-loop hardening, subagent review chains, red-flag detection, or skill-authoring work.
- Select `framework/60-spec-driven-development/` for Spec Kit-inspired work, specifications, requirements, acceptance criteria, project principles, clarification, technical plans, task breakdown, cross-artifact analysis, convergence, extension/preset/bundle governance, or third-party attribution.

## Agent and Model Routing

- Use the lowest-cost model class that satisfies the task's complexity and risk floor.
- Keep T0 and most T1 work on the lead agent when delegation overhead exceeds the work.
- Use bounded, non-overlapping sidecars for T2. Parallel specialists require positive delegation benefit and at least two independently owned workstreams.
- Use the strongest available model and independent verification for T4 security, production, migration, destructive, privacy, payment, or incident work.
- Reject risk score `3` without an explicit risk floor. Verify current agent and named-model availability before emitting a spawn or override decision.
- Reclassify and escalate when scope, ambiguity, failures, or risk increase.
- Cap every requested model and agent reasoning level at `medium`. Increase verification and topology for risk; never request a reasoning level above medium.
- For every non-trivial T1-T4 code change, spawn at least one bounded child when agent tooling is callable. Before the first project command or edit, expose the tier and spawned agent identity. The only valid no-spawn reason for code-changing work is `TOOL_UNAVAILABLE`.

## Frontend UI Tasks

Load only:

- `framework/08-performance/01-frontend-performance.md`
- `framework/10-frontend/00-frontend-architecture.md`
- `framework/14-ui/00-ui-excellence.md`
- `framework/15-ux/00-ux-excellence.md`
- `framework/16-accessibility/00-accessibility-excellence.md`
- `framework/27-quality-gates/08-ui-gate.md`
- `framework/27-quality-gates/09-ux-gate.md`
- `framework/27-quality-gates/10-accessibility-gate.md`
- `framework/27-quality-gates/05-performance-gate.md`
- `framework/27-quality-gates/16-ueef-activation-gate.md`

Apply UI UX Pro Max when available. Do not load backend, database, enterprise, or unrelated technology packs unless the task touches them.

For UI/UX work, this means loading and applying both `ui-ux-pro-max` and `impeccable`. Do not report UIUX as PASS when only one is available; report the missing skill according to the environment profile.

For frontend routes that render public, indexable, slow-to-boot, content-heavy, or data-heavy first views, evaluate SSR, SSG, streaming, route-level pre-rendering, or server components when supported by the stack. If client rendering remains the correct choice, record the project-specific reason.

### Design Engineering Skills

Keep `ui-ux-pro-max` and `impeccable` as the general UI/UX baseline. Add only the specialized installed skill whose trigger matches:

- `emil-design-eng` for animation implementation, motion polish, easing, timing, transitions, and interaction craft.
- `review-animations` for reviewing a motion diff or deciding whether animation changes pass.
- `improve-animations` for a read-only, whole-codebase motion audit and self-contained plans; respect its no-source-edits contract.
- `animation-vocabulary` only when naming or disambiguating a motion effect.
- `apple-design` for gesture-driven UI, springs, momentum, interruptibility, sheets, drag/swipe behavior, translucent depth, or Apple-style typography and motion.

Do not load all five by default. Multiple skills are selected together only when their triggers independently apply.

For every UI, frontend, page, component, form, dropdown, menu, modal, panel, table, dashboard, responsive, theme, or interaction task, first inspect `framework/46-design-system-consistency-reuse/` and select the relevant modules from `framework/47-theme-responsive-interaction-security-performance/`.

For large repositories, shared components, reusable services, validators, API clients, state utilities, tokens, and pattern libraries must be inspected before creating a custom implementation. If the behavior can be reused across more than one place, implement or extend it in the shared owner and import it into the target feature.
Related primitives, recipes, stories, tests, styles, documentation, and exports belong under one component-family owner folder. Do not create another shared folder for an existing semantic capability; extend the existing family and preserve one canonical public import.
For broad or unfamiliar repositories, run `scripts/project-context-map.ps1`, `scripts/project-context-map.sh`, or an equivalent repository map before implementation.

## Theme Tasks

Select pack 47 modules `01` through `07`: theme architecture; light, dark, and system modes; existing-theme compatibility; token enforcement; semantic colors; persistence and initialization; and theme accessibility.

## Responsive Page Tasks

Select pack 47 modules `10` through `16` plus `20`: responsive-first architecture, breakpoints and containers, fluid sizing, typography, components, tables and dashboards, forms, orientation, zoom, and short-height support.

## Dropdown Panel and Overlay Tasks

Select pack 47 modules `21`, `22`, `23`, `26` through `31`: global overlay contract, semantic surface contract, outside behavior, trigger toggle, single-open peers, Escape and focus, scroll restoration, and semantic layering.

## Security-Sensitive Tasks

Select pack 47 modules `36` through `40` plus pack 45 application-model and tenant modules when identity, authorization, entitlement, or tenancy is involved.

## Performance Tasks

Select pack 47 modules `41` through `46` and the relevant frontend, backend, API, database, React, Angular, .NET, SQL Server, or cloud technology module.

All applicable UI work includes `framework/27-quality-gates/19-theme-responsive-interaction-security-performance-gate.md` and `framework/28-scorecards/15-theme-responsive-interaction-security-performance-scorecard.md`.

## Design Governance Tasks

Select `framework/48-design-governance/` for design language, tokens, color, typography, iconography, spacing, sizing, radius, borders, shadows, elevation, motion, components, registry, patterns, layouts, templates, themes, responsive rules, interaction rules, overlays, drift, or no-reinvention work. Include `framework/46-design-system-consistency-reuse/` for reuse ownership and `framework/47-theme-responsive-interaction-security-performance/` for theme, responsive, overlay, accessibility, security, and performance contracts.

## Backend API Tasks

Load only:

- `framework/05-architecture/00-clean-architecture.md`
- `framework/07-security/00-security-by-default.md`
- `framework/08-performance/03-backend-performance.md`
- `framework/11-backend/00-backend-architecture.md`
- `framework/13-api/00-api-design.md`
- `framework/27-quality-gates/04-security-gate.md`
- `framework/27-quality-gates/05-performance-gate.md`
- `framework/27-quality-gates/07-api-gate.md`
- `framework/27-quality-gates/11-testing-gate.md`
- `framework/27-quality-gates/16-ueef-activation-gate.md`

Add database modules only when schema, query, persistence, migration, or transaction behavior is involved.

Backend performance checks include server-side pagination, filtering, sorting, aggregation, projection, caching/invalidation, cancellation, concurrency, serialization, authorization cost, and rate/burst behavior when the endpoint serves UI data or large collections.

## File Organization Tasks

For any task that creates files, selects output paths, scaffolds modules, generates artifacts, or reorganizes source, select `framework/26-decision-graphs/file-folder-decision-graph.md` and `framework/27-quality-gates/code-quality-gate.md`. New files must have an owner folder and lifecycle; root-level or standalone files require repository-standard justification.

For any task that creates a reusable component, service, validation rule, data mapper, API client, hook, store, directive, pipe, utility, layout, token, or pattern, select `framework/46-design-system-consistency-reuse/00-unified-design-system-architecture.md` and `framework/46-design-system-consistency-reuse/06-shared-frontend-services-validation-api.md` when applicable. Shared-first placement and import-based consumption are required unless the behavior is truly single-use.

## Database Tasks

Load only database, security, performance, migration, testing, and activation gates relevant to the database change.

## Documentation Tasks

Load only:

- `framework/18-documentation/00-documentation-engineering.md`
- `framework/24-ai-review/00-ai-review-system.md` when review quality matters
- `framework/27-quality-gates/12-documentation-gate.md`
- `framework/27-quality-gates/16-ueef-activation-gate.md`

## UEEF Maintenance Tasks

For UEEF-specific audit, install, validation, runtime, or rebuild work, broader loading is allowed. Still prefer targeted packs first, then expand only as needed.

## Engineering Guardian Selection

For every non-trivial task, select `framework/49-engineering-guardian/00-engineering-guardian.md`, `01-zero-regression-policy.md`, `19-self-criticism-engine.md`, `20-final-guardian-gate.md`, and `25-final-checklist.md`. Add monitors `02` through `18` for affected contracts, layers, systems, and quality dimensions. Add `21-engineering-health-score.md`, `22-long-term-maintenance.md`, `23-future-proof-review.md`, and `24-world-class-product-review.md` for releases, architecture changes, shared components, or high-risk work.

## Environment Bootstrap

Before all other task phases, run `scripts/environment-bootstrap.ps1` on Windows or `scripts/environment-bootstrap.sh` on Unix. Load `framework/50-environment-bootstrap/00-environment-bootstrap.md`, `01-profile-selection.md`, `02-core-profile.md`, `08-ai-profile.md`, `10-dependency-levels.md`, `11-detection-and-installation.md`, and `13-runtime-bootstrap-sequence.md`. Add Frontend, Backend, Database, UIUX, DevOps, or Optional profile modules only when task and repository evidence require them.

## Browser Tasks

For any page opening, navigation, browser inspection, clicking, typing, upload, download, or authenticated web workflow, select `framework/51-browser-session-control/`. The existing user-owned browser window and tab are mandatory. Load modules `00`, `01`, `02`, `03`, `04`, `05`, `06`, `07`, `08`, `09`, `10`, `11`, `12`, `13`, `14`, and `15`. For Chrome, read the installed Chrome control skill, bootstrap its browser client only through `mcp__node_repl__js`, use the Chrome plugin extension binding, enumerate `user.openTabs()`, and `claimTab()` the verified user tab; use visible Windows control only when that plugin is unavailable. Do not use directly exposed Playwright, Chrome DevTools, or in-app-browser MCP tools for Chrome work; Playwright is valid only through the claimed tab's `tab.playwright` API. A minimized, background, or non-foreground user window remains valid and must not pause the goal. A task-local Node REPL failure is `THREAD_CONTROL_CHANNEL_DEGRADED`, not Chrome unavailability; after the first failure use the Chrome readiness flow, automatic stale-ownership repair, and current same-tab evidence path rather than blocking, retrying visibly, or asking the user to restart Chrome. A claimed-tab ownership conflict must run `repair-chrome-tab-ownership.ps1`, rebootstrap the same extension, and reclaim once without a coordinator or user action. When the user asks to open a site, open a new tab only in that same Chrome window and profile. Preserve the user's Chrome window state; do not resize, emulate, move, restore, minimize, maximize, or alter full screen unless explicitly asked. Do not use a connector-created Chrome window, Codex-titled browser surface, newly created automation window, or unverified profile. If the user-owned tab cannot be proven by any authorized session after readiness recovery and handoff paths are exhausted, block instead of opening another browser.

## Skeleton Loading

For any data-backed UI, page, component, table, card, dashboard, form, or async interaction, select `framework/53-skeleton-loading/`. Load the system, structure-parity, state-contract, theme-responsive-accessibility, performance, reuse, verification, timing, SSR/hydration, and shared-API modules as applicable. Update an existing skeleton whenever the final content structure changes; never add a duplicate loader for the same region. Reusable skeleton primitives and proven recipes belong in the existing shared design-system owner, public API, and component registry. Require shared reveal/minimum-duration policy and deterministic server/client structure where applicable.

## Design Intelligence

For any UI audit, redesign, new visual system, or recommendation about fonts, colors, icons, strokes, outlines, radii, typography, spacing, motion, theme, or responsive behavior, select `framework/54-design-intelligence/` and run the repository design extractor before recommending new values. Classify every finding as extracted, inferred, or proposed.

For UEEF audits, releases, installer/runtime changes, security hardening, or broad quality work, select `framework/55-continuous-assurance/` and run the repository audit before and after edits.

For any table, data grid, collection list, dashboard data view, backend collection query, aggregate, export, or bulk data feature, select `framework/56-data-grid-platform/` and apply its frontend, backend, performance, security, and data-query contracts.

For any mutable remote state, live refresh, collaboration, notifications, counters, workflow state, background-job progress, or auto-refresh behavior, select `framework/47-theme-responsive-interaction-security-performance/51-global-live-refresh.md`. Add `framework/56-data-grid-platform/12-live-refresh-hardening.md` when query, collection, table, list, dashboard, or data-view semantics apply. Full page reload is not a normal synchronization strategy.

For any non-trivial route, feature, component, asset, locale, integration, worker, editor, chart, map, or optional backend capability, select `framework/47-theme-responsive-interaction-security-performance/50-application-lazy-loading.md` and the applicable frontend, backend, network, measurement, skeleton, accessibility, and security modules. Require a measured eager/lazy decision rather than mechanically splitting everything.

For any sidebar, header, navigation, application shell, route transition, page chrome, global animation, or shared loading-state work, select `framework/57-application-shell-design/` and apply its extraction, interaction, motion, responsive, accessibility, performance, and visual-QA contracts.

For any page, form, dashboard, landing view, or responsive layout, select `framework/27-quality-gates/30-visual-composition-gate.md` and require first-viewport composition, density, hierarchy, responsive, state, and visual-evidence review in addition to build/tests.

## Skill Invocation Protocol

For any task that names a skill, asks about agent workflows, asks to reuse external skill methodology, or changes UEEF's runtime behavior, select `framework/59-skill-invocation-protocol/00-skill-invocation-protocol-system.md`, the relevant child modules, and `framework/27-quality-gates/32-skill-invocation-protocol-gate.md`. The assistant must identify the skill candidates, choose the minimal skill chain, check red flags, and use fresh evidence before completion.

## Spec-Driven Development

For any broad, ambiguous, multi-file, high-impact, or durable feature, redesign, migration, integration, platform workflow, or agent-runtime change, select `framework/60-spec-driven-development/00-spec-driven-development-system.md`, the relevant child modules, and `framework/27-quality-gates/33-spec-driven-development-gate.md`. The assistant must keep requirements, plan, tasks, code, tests, and final claims traceable to the current specification or explicitly documented assumptions.

## Project Modernization

For broad refactoring, legacy cleanup, dead or obsolete code, architecture modernization, dependency or runtime upgrades, end-of-life technology, or whole-project improvement, select `framework/61-project-modernization/`, `framework/27-quality-gates/34-project-modernization-and-runtime-gate.md`, and the applicable architecture, code-quality, security, performance, testing, migration, Guardian, and continuous-assurance modules. Run `scripts/project-technology-inventory.mjs` before upgrade recommendations. Safe compatible upgrades may proceed with evidence; major or high-risk upgrades require an explicit user decision before mutation.

## Compact Verification Format

```text
UEEF: ACTIVE
Loaded: boot-loader, core-system
Selected: <count> modules
Gates: <count> gates
UIUX: YES/NO/NA
```

Do not repeat full module rules in the final response unless the user asks for them.
