---
name: design-system-guardian
description: Audit and protect a repository frontend design system. Use when changing CSS, SCSS, tokens, themes, typography, spacing, radii, shadows, motion, focus, density, icons, generated styles, or shared UI components.
---

# Design System Guardian

## Inspect first

- Find token sources, aliases, themes, generated outputs, and build scripts.
- Find shared primitives, registries, approved variants, and consumers.
- Inspect Stylelint, framework linting, Storybook, and visual-regression configuration.

## Guardrails

- Prefer semantic tokens over raw palette or scale values.
- Reject arbitrary component-local values when an approved token exists.
- Never edit generated token output directly or duplicate an existing shared component or variant.
- Require every new token to have semantic purpose, theme values, owner, and usage example.
- Use logical properties for directional layout and flag physical left/right declarations that break RTL.
- Resolve CSS custom-property references and flag unknown or circular aliases.
- Keep primitive, semantic, component, and generated token layers separate.
- Preserve focus visibility, contrast, reduced motion, and high-zoom usability.
- Do not weaken a lint rule globally to bypass a local exception.
- Review shared-token impact across affected consumers and visual evidence.

## Review output

Return raw/duplicated values, reuse opportunities, RTL hazards, accessibility implications, generated files and tests affected, exact safe fixes, and owned intentional exceptions.
