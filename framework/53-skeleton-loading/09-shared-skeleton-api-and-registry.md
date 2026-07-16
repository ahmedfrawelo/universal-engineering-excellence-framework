# Shared Skeleton API And Registry

Provide one framework-native skeleton API in the existing design-system or shared UI owner. Its public API must expose governed primitives for text, block, media, and avatar geometry plus composed recipes for proven structures such as lists, cards, tables, dashboards, and page regions. Do not skeletonize action controls, menus, dialogs, notifications, or unknown structures by default; use an appropriate progress or pending state instead.

The shared API owns variants, line and row policy, semantic sizing, tokenized color, radius, spacing, motion, reveal timing, minimum duration, reduced-motion behavior, and decorative accessibility defaults. Consumers provide semantic structure and domain layout, not raw visual constants. Keep the API narrow, typed where the stack supports it, tree-shakeable, and independent of feature data access.

Register every public primitive and recipe in the component registry with its owner, import path, supported states, responsive limits, token dependencies, examples, tests, adoption status, and deprecation path. Export it from the established public entrypoint. A new recipe requires either two real consumers or a documented cross-product contract; otherwise compose shared primitives locally without creating a competing base component.

Verification requires contract tests, an architecture or lint check against duplicate local primitives, and at least one real consumer. Breaking changes require versioning and migration notes.

## Component Family Organization

Use one skeleton family folder in the established shared UI or design-system owner. Keep the canonical primitive, public entrypoint, tests, stories, styles, and documentation at that family boundary. Put reusable layouts such as shell, table, list, card, or dashboard recipes in named child folders and export them through the same public entrypoint.

Do not create parallel shared folders such as `skeleton`, `skeleton-loader`, and `shell-skeleton` when they overlap. A shell or table recipe is valid only when it consumes the canonical primitive and owns structure rather than another shimmer, token, timing, or accessibility implementation. Search selectors, filenames, registry entries, barrel exports, and imports before creating. Reuse when complete, extend the family when additions are required, and create only when no compatible skeleton owner exists.
