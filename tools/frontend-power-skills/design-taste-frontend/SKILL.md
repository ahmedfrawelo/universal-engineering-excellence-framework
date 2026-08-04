---
name: design-taste-frontend
description: Anti-slop frontend direction for landing pages, portfolios, and visual redesigns. Infer the brief, choose a coherent visual system, then implement and verify a distinctive production interface.
---

# Taste frontend entrypoint

<!-- UEEF-PROGRESSIVE-ENTRYPOINT -->

Use this skill for expressive marketing pages, portfolios, editorial surfaces, and visual redesigns. Do not use it as the primary skill for dashboards, data tables, or multi-step product workflows.

The complete pinned upstream skill is preserved at `references/upstream-full.md`. Read that reference only when the task needs its detailed design-system map, canonical animation skeletons, pattern vocabulary, redesign decision tree, block-library contract, installation commands, or source appendices. This entrypoint contains the rules required on every invocation.

## Required workflow

1. Read the brief before choosing an aesthetic. Infer page kind, audience, vibe, references, existing brand assets, and accessibility or regulatory constraints.
2. State one concise design read: page kind, audience, visual language, and likely system or aesthetic family. Ask one question only when materially different directions remain plausible.
3. Set three explicit dials from 1 to 10: `DESIGN_VARIANCE`, `MOTION_INTENSITY`, and `VISUAL_DENSITY`. A mainstream landing page usually starts near `7 / 6 / 4`; adapt to the brief.
4. For redesigns, audit the existing page and assets before editing. Preserve brand identity, content, URLs, behavior, accessibility, and working integrations unless the user explicitly changes them.
5. Inspect the owning architecture, design system, tokens, shared components, and installed dependencies. Use official packages only when a real design system fits the brief; verify dependencies before importing them.
6. Implement one coherent direction. Reuse shared primitives and existing tokens. Keep consumer defaults explicit and avoid page-local duplication of reusable behavior.
7. Verify responsive behavior, both supported themes, keyboard and focus states, reduced motion, loading/error/empty states, and the requested behavior in the permitted live browser when browser validation is in scope.
8. Run the repository's focused checks and the applicable UEEF frontend gate. Never claim visual completion from build success alone.

## Always-on taste rules

- Do not default to purple gradients, a centered hero on a dark mesh, three equal feature cards, indiscriminate glassmorphism, endless ambient animation, or generic placeholder content.
- Let the audience and content determine hierarchy. Use intentional asymmetry only when the design read supports it.
- Typography must have a clear scale, controlled line length, and deliberate weight contrast. Avoid arbitrary font mixing and tiny low-contrast body text.
- Color must come from a small semantic palette with accessible contrast. Do not add isolated hex values when tokens exist.
- Cards are not a default layout primitive. Use grouping, whitespace, dividers, background shifts, and composition before adding another bordered rounded rectangle.
- Every interactive element needs visible hover, focus, active, disabled, and loading behavior where applicable.
- Layout must not create horizontal overflow, clipped focus rings, unreadable text, or fixed heights that break with real content.
- Prefer real, relevant assets. Preserve supplied logos and photography; do not silently replace brand material.
- Use realistic domain content. Do not ship generic dummy copy, fake metrics, fake testimonials, or invented integrations as though they were real.
- Do not use emoji as UI icons. Use the project's icon system or an appropriate accessible icon library.
- Motion must support meaning, remain interruptible, respect `prefers-reduced-motion`, and favor `transform` and `opacity`. Avoid scroll-jacking and decorative animation that delays interaction.
- Dark mode is a designed theme, not an inversion. Test contrast, surfaces, borders, shadows, media, and focus states independently.
- Avoid em dashes in generated product copy unless the existing content style explicitly uses them.
- Never fabricate tests, screenshots, package availability, links, data, or visual verification.

## Load the full reference when needed

Read `references/upstream-full.md` before acting when any of these applies:

- selecting among Material, Fluent, Carbon, Radix, Primer, GOV.UK, USWDS, Atlassian, Bootstrap, Polaris, or another named system;
- implementing sticky-stack, horizontal-pan, scroll-reveal, gallery, kinetic typography, or another advanced motion pattern;
- using the detailed AI-tell audit, reference vocabulary, or final pre-flight catalog;
- performing a preserve-versus-overhaul redesign decision;
- creating or consuming reusable blocks from the Taste block library;
- needing upstream install commands, canonical sources, or the Apple Liquid Glass web approximation guidance.

When the full reference is loaded, its contextual guidance applies only where it fits the brief and does not override the user, repository ownership, existing design system, accessibility, or UEEF completion rules.
