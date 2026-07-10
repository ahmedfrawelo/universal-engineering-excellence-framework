# User-Owned Browser

The user's opened browser is the source of truth for browser tasks that depend on tabs, extensions, cookies, or login state.

- Use visible Windows control for the user's active browser window when exact window identity matters. A browser connector is allowed only when it proves attachment to that same visible window without creating a new surface.
- Never substitute a headless browser, temporary profile, Playwright-launched context, or unrelated browser profile silently.
- Preserve the user's current tabs and do not close, replace, or navigate unrelated tabs.
- If the user names Chrome or the in-app browser, follow that explicit surface choice.
