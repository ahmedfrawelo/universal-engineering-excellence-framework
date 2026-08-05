# Frontend Task Modes

Route frontend work through `scripts/select-frontend-route.mjs`. Its orthogonal fields are authoritative: `intent` describes Change, Audit, or Recommend; `scope` describes Quick, Build, or Broad; `mutation` distinguishes Implement from ReadOnly; and `domains` selects only the relevant specialist packs. `frontendMode` remains a compatibility projection, not the source of truth. Every automated route must retain `reasons`, `matchedSignals`, and `confidence` so unexpected selection is diagnosable.

Version: 1.0
Pack: 10-frontend/01-engineering
Status: Stable
Applies To: frontend routing, skill selection, module selection, and verification depth

## Purpose

Frontend work must receive the smallest workflow that can prove the requested outcome. A local CSS fix, a new production page, and a design audit are different tasks and must not inherit the same modules, skills, or gates.

## Mode Selection

Choose exactly one frontend mode before loading optional UI modules:

| Mode | Use when | Do not expand into |
| --- | --- | --- |
| `Quick` | A bounded change to an existing component, style, label, state, or interaction whose owner and intended behavior are already clear | Broad design-system discovery, visual-composition audit, performance audit, or full responsive review unless the changed behavior requires it |
| `Build` | Creating or materially extending a page, route, component family, form, dashboard, layout, or production interaction | Whole-product design governance or unrelated visual review |
| `Audit` | Reviewing, critiquing, redesigning, visually polishing, or measuring an existing frontend or design system | Implementation unless the user also requested implementation |

An explicit mode selected by the user or task owner wins. Otherwise infer the mode from the requested outcome, not from the presence of generic words such as `frontend`, `component`, `CSS`, or `design`.

## Module and Gate Budget

### Quick

- Load `00-frontend-engineering.md`, the focused UI module, and the accessibility module only when the changed behavior needs it.
- Inspect the current component family and its direct tokens or shared owner. Do not map the whole repository for a bounded known-owner change.
- Apply the UI gate plus focused code, test, and accessibility checks. Add UX, performance, responsive, theme, or overlay gates only when the change touches those contracts.
- Preserve or update an existing skeleton only when the final content structure or loading behavior changes. Do not introduce a skeleton workflow merely because the component receives data.
- Visual browser evidence is optional unless the user explicitly asks for visual verification or the exact visual result is the acceptance criterion.

### Build

- Load frontend, UI, UX, accessibility, and performance foundations relevant to the new surface.
- Inspect the relevant shared owners, tokens, registries, and layouts before creating a parallel primitive. Search only the boundaries that can plausibly own the capability.
- Apply UI, UX, accessibility, testing, and proportionate performance gates.
- Add the visual-composition gate for a new or materially changed page, layout, form, dashboard, landing view, or responsive surface.
- Select skeleton modules only for a new or materially changed asynchronous loading region.

### Audit

- Load the design-intelligence or design-governance modules that match the audit question plus the affected frontend foundations.
- Apply visual-composition, UI, UX, accessibility, and performance gates only to claims made by the audit.
- Keep a report-only audit read-only until the user requests implementation.
- Require rendered evidence only when the audit makes visual or interaction claims. Browser control still requires an explicit browser task.

## Skill Routing

Skills are selected by purpose, not stacked as a universal baseline:

- `typeui-fundamentals`: lightweight principles for layout, typography, interaction, or accessibility when those decisions are present.
- `frontend-design`: building or materially extending a production frontend.
- `interface-design`: sole primary director for dashboards, admin tools, SaaS, settings, and dense product UI.
- `design-taste-frontend`: a supplementary taste layer only for landing pages, portfolios, marketing surfaces, and expressive redesigns; never select it for dashboards, admin tools, data grids, or dense product UI.
- `styleseed-design-review`: a measured post-build review when scoring or material visual release review is requested; its 80-point floor does not replace behavioral evidence.
- `frontend-ui-engineering`: framework-neutral production implementation craft after selecting a visual direction; do not stack it onto Angular routes.
- `angular-developer`: the implementation authority for Angular work, including architecture and framework-specific code.
- `company-data-table` and `angular-table-harness`: custom data-grid behavior and stable Angular test APIs.
- `responsive-craft`: responsive transformations and breakpoint-specific design decisions.
- `design-system-guardian`: tokens, shared primitives, themes, and drift prevention.
- `frontend-visual-qa`: deterministic visual verification under the active browser policy.
- `performance-optimization`, `code-review-and-quality`, and `source-driven-development`: evidence-driven specialist routes.
- `prototype` and `extract-design-system`: explicit-only ideation and reference extraction routes.
- `impeccable`: critique, audit, redesign, or visual polish.
- `ui-ux-pro-max`: product/style intelligence such as style direction, palettes, typography pairings, product patterns, or explicit broad UI/UX recommendations.
- Specialist motion skills: only when their own trigger applies.

`browser-testing-with-devtools` is intentionally never auto-selected: its isolated or alternate Chrome profile conflicts with UEEF browser-session ownership. Installation does not grant tool authority.

No UI skill is mandatory merely because a task mentions `frontend` or `component`. Multiple skills are used together only when their independent triggers are both part of the requested outcome.

For material design production, load `framework/10-frontend/02-production-design/`. Treat `DESIGN.md` as the durable design contract, and use Penpot as the preferred canvas for new UEEF-controlled design work only after live MCP health is proved. Explicit supplied Figma artifacts remain on Figma.

## Escalation Rules

Escalate `Quick` to `Build` when the change creates a new reusable owner, changes multiple surfaces, alters responsive structure, or introduces a new async interaction. Escalate to `Audit` when the requested outcome becomes critique, redesign, visual parity, or broad design-system judgment.

Do not escalate solely because the repository is large, the component consumes data, or optional design skills are installed.

## Required Evidence

- The selected mode and why it matches the requested outcome.
- The smallest relevant module, skill, and gate set.
- Focused tests or static checks for changed behavior.
- Rendered or browser evidence only when required by the requested acceptance criterion.

## Failure Conditions

- A `Quick` task loads the complete design, responsive, performance, skeleton, or visual-audit suite without a touched contract.
- A `Build` task skips relevant shared-owner discovery or production UI/UX/accessibility checks.
- An `Audit` claim is presented as visually verified without rendered evidence.
- Both general design skills are applied only because the task is frontend work.
- Missing optional skills block a change that can be implemented and verified with project evidence.
