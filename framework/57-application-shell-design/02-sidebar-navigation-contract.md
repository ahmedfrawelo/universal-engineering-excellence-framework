# Sidebar and Navigation Contract

- Navigation items use stable IDs, route targets, labels, icons, permission rules, feature flags, and optional badge data.
- Active state follows the resolved route, not click history. Parent groups reflect the active descendant and preserve intentional expansion state.
- Collapse/expand has a persistent preference, an accessible label, a compact icon-only mode with tooltips, and a mobile drawer mode with focus management.
- Outside dismissal, Escape, focus return, scroll locking, nested menus, and collision behavior are explicit.
- Do not hide the only route access behind hover. Keyboard and touch paths must be equivalent.
- Preserve state across navigation only where it is useful and safe; reset stale route-specific state when the resource changes.
