# UIUX Profile

Version: 1.4.0
Status: Enforced

## Purpose

Discovers optional UI design skills without turning their installation into a universal frontend blocker.

## Required Practice

- Verify only skills selected by the frontend mode and task trigger. Figma MCP may be added when scope requires it. For Chrome interaction, select the Chrome plugin and Node REPL path; directly exposed Playwright and Chrome DevTools MCPs are not valid substitutes.
- Classify every dependency as Mandatory, Recommended, or Optional.
- Emit Environment Ready, Profiles Loaded, Mandatory Dependencies, Recommended Dependencies, Optional Dependencies, Missing Items, Installation Performed, and Validation Result.
- Treat `typeui-fundamentals` as Recommended for UI fundamentals. Treat `ui-ux-pro-max`, `impeccable`, `frontend-design`, `design-brief`, `emil-design-eng`, `review-animations`, `improve-animations`, `animation-vocabulary`, and `apple-design` as conditional or Optional capabilities selected only by their triggers.
- A missing optional design skill warns only when its trigger applies and never blocks unrelated UI work.
- Detect `frontend-design` and `design-brief` as Optional Open Design specialists; use them only when their frontend implementation or design-planning triggers match.
- Missing specialist skills must not block unrelated UI work; select them only for matching tasks.
- When browser interaction is required, add Browser Session Control and require the user's existing browser and tab; browser session access is not satisfied by an isolated browser.

## Evidence

- [ ] Current command, path, version, skill, MCP, or runtime evidence is recorded.
- [ ] Profile selection is traceable to task or repository evidence.
- [ ] READY/BLOCKED/WARN matches the dependency policy.

## Failure Conditions

- Mandatory gaps are ignored or hidden.
- The checker claims readiness without current evidence.
- A fixed universal tool list blocks unrelated work.

## Related Modules

- framework/01-core/01-master-loader.md
- framework/03-runtime/00-runtime-sequence.md
- framework/50-environment-bootstrap/10-dependency-levels.md
