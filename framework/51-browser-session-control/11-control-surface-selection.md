# Browser Control Surface Selection

Use the least intrusive control surface that can complete the user's browser task.

## Default Selection

- For Chrome work, the Chrome plugin skill and Chrome plugin extension binding are mandatory. Read its installed `control-chrome/SKILL.md`, initialize its `browser-client.mjs` only through `mcp__node_repl__js`, select `agent.browsers.get("extension")`, and claim the verified existing tab returned by `user.openTabs()` for navigation, clicks, typing, screenshots, and inspection.
- Do not use directly exposed `mcp__playwright__*`, `mcp__chrome_devtools__*`, in-app-browser, or standalone automation tools for Chrome work. Their presence does not prove ownership of the user's Chrome window. Playwright is allowed only as the claimed tab's in-plugin `tab.playwright` API.
- Use the claimed tab's DOM, console, network, or performance capabilities only when the task needs them.
- Use visible Windows control only when the Chrome plugin is unavailable; never switch surfaces merely to bypass a recoverable stale tab binding.

## User Indicators

- Visible Windows fallback may show a temporary screen-edge highlight. A newly created automation/debugging browser is prohibited; extension attachment to the existing user tab is allowed.
- These indicators are platform safety disclosures and must not be hidden or suppressed.
- If a debugging banner appears, verify whether a separate automation browser was created. Stop and release it if so; do not abandon a healthy extension-bound user tab.

## Completion Rule

Keep one selected control surface for the task unless a documented capability gap requires a switch. Never switch silently to a new browser, profile, or automation window.
