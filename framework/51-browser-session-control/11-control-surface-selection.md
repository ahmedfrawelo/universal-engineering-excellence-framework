# Browser Control Surface Selection

Use the least intrusive control surface that can complete the user's browser task.

## Default Selection

- For Chrome work, the Chrome plugin skill and Chrome plugin extension binding are mandatory. Read its installed `control-chrome/SKILL.md`, initialize its `browser-client.mjs` only through `mcp__node_repl__js`, select `agent.browsers.get("extension")`, and claim the verified existing tab returned by `user.openTabs()` for navigation, clicks, typing, screenshots, and inspection.
- Do not use directly exposed `mcp__playwright__*`, `mcp__chrome_devtools__*`, `browser_*`, Cursor/IDE Simple Browser, in-app-browser, `browser.newContext`, `browser.launch`, or standalone automation tools as ordinary Chrome substitutes. Playwright is allowed only as the claimed tab's in-plugin `tab.playwright` API. A direct Chrome DevTools/CDP adapter is an exception only under the `AUTHORIZED_LOOPBACK_LAST_RESORT` contract below.
- An isolated/local browser test is allowed only after an explicit separate user request. It must not open a second browser as fallback, and it never satisfies a user-owned Chrome task or its visual verification.
- Use the claimed tab's DOM, console, network, or performance capabilities only when the task needs them.
- Use visible Windows control only on Windows when the Chrome plugin is unavailable; on macOS/Linux skip it and continue only to an eligible authorized loopback stage, otherwise stop and ask for the existing tab. Never switch surfaces merely to bypass a recoverable stale tab binding.

## Authorized Loopback Last Resort

This stage is eligible only after every `requiredPriorStages` entry in `config/browser-emergency-fallback.json` has recorded failure evidence, the user explicitly authorizes it, and `scripts/get-remote-debugging-readiness.ps1 -AuthorizedLastResort -PriorStageFailure <recorded-stages>` returns `READY_LAST_RESORT`; missing evidence returns `PRIOR_STAGES_INCOMPLETE`. Attach to the matching existing page target through a loopback-only endpoint such as `127.0.0.1:9222`; do not launch or navigate to discover a substitute target. Cookie, storage, password, profile-directory, and history inspection are prohibited. Detach when verification finishes. A stricter system, host, plugin, or installed-skill rule overrides this exception.

## User Indicators

- Visible Windows fallback may show a temporary screen-edge highlight. A newly created automation/debugging browser is prohibited; extension attachment to the existing user tab is allowed.
- These indicators are platform safety disclosures and must not be hidden or suppressed.
- If a debugging banner appears, verify whether a separate automation browser was created. Stop and release it if so; do not abandon a healthy extension-bound user tab.

## Completion Rule

Keep one selected control surface for the task unless a documented capability gap requires a switch. Never switch silently to a new browser, profile, or automation window.
