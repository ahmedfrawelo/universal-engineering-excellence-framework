# Shell Loading and State Reconciliation

- Use structural shell skeletons for first load and local placeholders for route-specific regions; preserve known chrome when only data changes.
- Distinguish bootstrap, route loading, background refresh, permission resolution, offline, stale, retrying, and fatal states.
- Reconcile navigation badges, unread counts, identity, permissions, theme, and route metadata after refresh or realtime events without resetting user context.
- Prevent layout shift by reserving shell, header, sidebar, and overlay dimensions.
- Define what remains interactive during loading and what is blocked, with an accessible status announcement.
