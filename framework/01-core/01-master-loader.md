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

For every UI, frontend, page, component, form, dropdown, menu, modal, panel, table, dashboard, responsive, theme, or interaction task, first inspect `framework/46-design-system-consistency-reuse/` and select the relevant modules from `framework/47-theme-responsive-interaction-security-performance/`.

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

For any page opening, navigation, browser inspection, clicking, typing, upload, download, or authenticated web workflow, select `framework/51-browser-session-control/`. The existing user-owned browser window and tab are mandatory. Load modules `00`, `01`, `02`, `04`, `05`, `06`, `07`, `08`, and `09`. For tasks that depend on the exact browser window the user is viewing, use visible Windows window control first. Do not use a connector-created Chrome window, Codex-titled browser surface, automation-banner window, or unverified profile. If a connector exposes a blank or wrong tab, run read-only tab discovery and user-tab recovery before blocking. If the visible window cannot be proven after recovery, block instead of opening another browser.

## Skeleton Loading

For any data-backed UI, page, component, table, card, dashboard, form, or async interaction, select `framework/53-skeleton-loading/`. Load the system, structure-parity, state-contract, theme-responsive-accessibility, performance, reuse, and verification modules as applicable. Update an existing skeleton whenever the final content structure changes; never add a duplicate loader for the same region.

## Design Intelligence

For any UI audit, redesign, new visual system, or recommendation about fonts, colors, icons, strokes, outlines, radii, typography, spacing, motion, theme, or responsive behavior, select `framework/54-design-intelligence/` and run the repository design extractor before recommending new values. Classify every finding as extracted, inferred, or proposed.

For UEEF audits, releases, installer/runtime changes, security hardening, or broad quality work, select `framework/55-continuous-assurance/` and run the repository audit before and after edits.

For any table, data grid, list, dashboard data view, backend query endpoint, export, notification feed, auto-refresh, or realtime data feature, select `framework/56-data-grid-platform/` and apply its frontend, backend, performance, security, and realtime contracts.

For any sidebar, header, navigation, application shell, route transition, page chrome, global animation, or shared loading-state work, select `framework/57-application-shell-design/` and apply its extraction, interaction, motion, responsive, accessibility, performance, and visual-QA contracts.

For any page, form, dashboard, landing view, or responsive layout, select `framework/27-quality-gates/30-visual-composition-gate.md` and require first-viewport composition, density, hierarchy, responsive, state, and visual-evidence review in addition to build/tests.

## Compact Verification Format

```text
UEEF: ACTIVE
Loaded: boot-loader, core-system
Selected: <count> modules
Gates: <count> gates
UIUX: YES/NO/NA
```

Do not repeat full module rules in the final response unless the user asks for them.
