# UIUX Profile

Version: 1.4.0
Status: Enforced

## Purpose

Requires both UI UX Pro Max and Impeccable for UI work, plus relevant browser tools.

## Required Practice

- Verify both skills together. Figma MCP may be added when scope requires it. For Chrome interaction, select the Chrome plugin and Node REPL path; directly exposed Playwright and Chrome DevTools MCPs are not valid substitutes.
- A UI task must not report UIUX PASS when either core design skill is missing.
- Classify every dependency as Mandatory, Recommended, or Optional.
- Emit Environment Ready, Profiles Loaded, Mandatory Dependencies, Recommended Dependencies, Optional Dependencies, Missing Items, Installation Performed, and Validation Result.
- For UI/UX work, both `ui-ux-pro-max` and `impeccable` are Mandatory and must be selected together.
- The bootstrap result must list both skill names under Mandatory Dependencies and mark UIUX PASS only after both paths are verified.
- Treat `emil-design-eng` as Recommended for UIUX work. Detect `review-animations`, `improve-animations`, `animation-vocabulary`, and `apple-design` as Optional specialist capabilities.
- Missing specialist motion skills must not block unrelated UI work; select them only for matching tasks.
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
