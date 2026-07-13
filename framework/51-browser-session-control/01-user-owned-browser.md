# User-Owned Browser

The user's opened browser is the source of truth for browser tasks that depend on tabs, extensions, cookies, or login state.

- For Chrome, read the installed Chrome control skill, bootstrap its browser client through `mcp__node_repl__js`, use the extension binding, and claim the exact tab returned by `user.openTabs()`. Use visible Windows control only as fallback when the plugin is unavailable. A connector is valid only when it attaches to that same visible window without creating a new surface.
- Never substitute a headless browser, temporary profile, Playwright-launched context, or unrelated browser profile silently.
- Preserve the user's current tabs and do not close, replace, or navigate unrelated tabs.
- If the user names Chrome or the in-app browser, follow that explicit surface choice.
