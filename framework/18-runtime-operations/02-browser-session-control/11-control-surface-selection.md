# Browser Control Surface Selection

Use the least intrusive control surface that can complete the user's browser task.

## Default Selection

- For Chrome work, the Chrome plugin skill and explicit Chrome-family binding are mandatory. Read its installed `control-chrome/SKILL.md`, initialize `browser-client.mjs` only through `mcp__node_repl__js`, select `agent.browsers.get("chrome")` or the current skill-documented Chrome-family selector, read the browser documentation in full, prove the existing user window/profile/session through `user.openTabs()`, create a dedicated task tab through that same binding, and claim the exact created tab for navigation, clicks, typing, screenshots, and inspection.
- Do not use directly exposed `mcp__playwright__*`, `mcp__chrome_devtools__*`, `browser_*`, Cursor/IDE Simple Browser, in-app-browser, `browser.newContext`, `browser.launch`, or standalone automation tools as ordinary Chrome substitutes. Playwright is allowed only as the claimed tab's in-plugin `tab.playwright` API. A direct Chrome DevTools/CDP adapter is an exception only under the `AUTHORIZED_LOOPBACK_LAST_RESORT` contract below.
- An isolated/local browser test is allowed only after an explicit separate user request. It must not open a second browser as fallback, and it never satisfies a user-owned Chrome task or its visual verification.
- Do not call `getDefault()`, `getForUrl()`, or `get("iab")` for a UEEF Chrome task; those selectors may choose the in-app browser and violate surface identity.
- Use the claimed dedicated tab's DOM, console, network, or performance capabilities only when the task needs them.
- Use visible Windows control only on Windows when the Chrome plugin is unavailable; on macOS/Linux skip it and continue only to an eligible authorized loopback stage, otherwise stop and ask for the existing tab. Never switch surfaces merely to bypass a recoverable stale tab binding.

## Authorized Loopback Last Resort

This stage is eligible only after every `requiredPriorStages` entry in `config/browser-emergency-fallback.json` has recorded failure evidence, the user explicitly authorizes it, and `scripts/get-remote-debugging-readiness.ps1 -AuthorizedLastResort -PriorStageFailure <recorded-stages> -ExpectedTargetId <dedicated-target-id>` returns `READY_LAST_RESORT` with `sameTargetProven`; missing evidence returns `PRIOR_STAGES_INCOMPLETE`. The HTTP endpoint plus browser and exact page-target WebSockets must all remain loopback-only. Do not launch or navigate to discover a substitute target. Cookie, storage, password, profile-directory, and history inspection are prohibited. Detach when verification finishes. A stricter system, host, plugin, or installed-skill rule overrides this exception.

## User Indicators

- Visible Windows fallback may show a temporary screen-edge highlight. A newly created automation/debugging browser is prohibited; control must remain on the dedicated task tab inside the verified existing Chrome window.
- These indicators are platform safety disclosures and must not be hidden or suppressed.
- If a debugging banner appears, verify whether a separate automation browser was created. Stop and release it if so; do not abandon a healthy extension-bound user tab.

## Completion Rule

Keep the selected Chrome binding and dedicated task tab for the task unless a documented capability gap requires an authorized same-target channel switch. Never switch silently to a new browser, profile, session, panel, in-app browser, or automation window.
