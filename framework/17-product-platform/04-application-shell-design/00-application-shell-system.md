# Application Shell System

Treat the shell as a shared product surface with one interaction contract. It owns global navigation, identity context, page chrome, notifications, overlays, responsive mode, and transition coordination.

## Required Analysis

- Identify the shell root, sidebar/navigation source, header source, route outlet, page-header pattern, overlay host, notification host, theme tokens, and loading boundary.
- Record which state is URL-owned, user-preference-owned, session-owned, permission-owned, or server-owned.
- Trace desktop, tablet, mobile, RTL, keyboard, zoom, reduced-motion, loading, error, and unauthorized states.
- Reuse existing shell components and tokens. A feature may extend a shared contract but must not fork global behavior.

## Completion Rule

The shell is complete only when structure, content hierarchy, interaction states, motion, responsive behavior, accessibility, loading, error recovery, and visual evidence are documented and tested together.
