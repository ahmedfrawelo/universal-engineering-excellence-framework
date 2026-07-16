# Shared Skeleton API And Registry

Provide one framework-native skeleton API in the existing design-system or shared UI owner. Its public API must expose governed primitives for text, block, media, and avatar geometry plus composed recipes for proven structures such as lists, cards, tables, dashboards, and page regions. Do not skeletonize action controls, menus, dialogs, notifications, or unknown structures by default; use an appropriate progress or pending state instead.

The shared API owns variants, line and row policy, semantic sizing, tokenized color, radius, spacing, motion, reveal timing, minimum duration, reduced-motion behavior, and decorative accessibility defaults. Consumers provide semantic structure and domain layout, not raw visual constants. Keep the API narrow, typed where the stack supports it, tree-shakeable, and independent of feature data access.

Register every public primitive and recipe in the component registry with its owner, import path, supported states, responsive limits, token dependencies, examples, tests, adoption status, and deprecation path. Export it from the established public entrypoint. A new recipe requires either two real consumers or a documented cross-product contract; otherwise compose shared primitives locally without creating a competing base component.

Verification requires contract tests, an architecture or lint check against duplicate local primitives, and at least one real consumer. Breaking changes require versioning and migration notes.
