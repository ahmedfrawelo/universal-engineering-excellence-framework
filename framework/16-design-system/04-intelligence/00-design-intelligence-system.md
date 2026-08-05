# Design Intelligence System

Before styling or redesigning a UI, inspect the product's source of truth and run `scripts/extract-design-system.mjs <project-root> <report-path>`. Use the report as evidence, then inspect the authoritative files it identifies before changing code.

Run `scripts/recommend-design-system.mjs <extraction-report> <recommendations-path>` after extraction for a bounded, priority-ranked review. Recommendations are inferred review prompts, never automatic approval or automatic design changes.

The decision order is: existing governed token or component, existing project asset/library, a semantic extension in the same source of truth, then a documented recommendation. Never start with a new font, palette, icon library, outline weight, radius, or type scale because it looks attractive in isolation.
