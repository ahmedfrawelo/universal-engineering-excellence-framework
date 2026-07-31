---
name: frontend-visual-qa
description: Verify frontend changes in the permitted live browser, Storybook, or deterministic visual routes. Use after UI implementation or for layout, responsive, theme, RTL, accessibility, interaction, or visual-regression defects.
---

# Frontend Visual QA

Follow the active platform and UEEF browser policy. This skill never authorizes a second browser, profile, context, or forbidden browser tool.

## Evidence matrix

- Applicable widths among 375, 768, 1024, and 1440 plus a real transition width.
- RTL/LTR, keyboard-only, 200% zoom, reduced motion, long Arabic, long English, mixed direction, and null data.
- Loading, empty, no-results, error, sorting, filtering, selection, actions, and pagination.
- Additional engines only through an already-authorized project test suite.

## Rules

- Use deterministic fixtures and wait for fonts and data.
- Inspect console, network, DOM, computed styles, accessibility tree, and scroll regions when authorized.
- Compare the smallest useful surface against approved baselines.
- Fix nondeterminism instead of increasing diff tolerance and never update snapshots only to pass CI.
- Record every accepted visual change and governing requirement or token.

## Automation boundary

- Automate deterministic screenshots, ARIA snapshots, axe scans, interaction checks, overflow assertions, and configured cross-engine smoke tests.
- Manually review keyboard flow, screen-reader meaning, zoom usability, hierarchy, content clarity, and focus visibility.
- Automated accessibility checks never replace manual keyboard, screen-reader, zoom, focus, and long-content review.
- Browser authorization comes from active platform policy, never from this skill.

## Completion report

Return exact commands, environments, screenshots/diffs, failures fixed, accepted baseline changes, accessibility evidence, browser differences, and remaining manual checks.
