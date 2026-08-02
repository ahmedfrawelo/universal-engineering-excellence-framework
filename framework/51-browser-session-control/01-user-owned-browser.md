# User-Owned Browser

The user's opened browser is the source of truth for browser tasks that depend on tabs, extensions, cookies, or login state.

- For Chrome, read the installed Chrome control skill, bootstrap its browser client through `mcp__node_repl__js`, select Chrome explicitly with `agent.browsers.get("chrome")` or the skill-documented Chrome-family selector, and read the binding documentation in full. Use `user.openTabs()` only to prove the existing window/profile/session; then create a dedicated task tab through that same binding and claim the exact created tab. Reuse a user's existing working tab only by explicit request. Visible Windows control is a Windows-only fallback when the plugin is unavailable. On macOS/Linux, stop and ask the user to activate Chrome; do not invent another control surface.
- Never substitute a headless browser, temporary profile, Playwright-launched context, or unrelated browser profile silently.
- Preserve the user's current tabs and do not close, replace, or navigate unrelated tabs.
- UEEF browser tasks default to the user's Chrome. The in-app browser is forbidden unless the user explicitly requests that distinct surface as a separate task; it is never a fallback for Chrome.
