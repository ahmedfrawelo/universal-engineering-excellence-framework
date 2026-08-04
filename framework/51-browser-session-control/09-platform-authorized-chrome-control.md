# Platform-Authorized Chrome Control

When a user asks to inspect, test, navigate, or operate a website in Chrome, select the installed Chrome family explicitly, prove the existing user-owned window/profile/session, and create a dedicated task tab inside it. Do not claim or navigate the user's working tab unless explicitly requested. Visible Windows control is available only on Windows if the plugin is unavailable; on macOS/Linux skip it and continue only to an eligible `AUTHORIZED_LOOPBACK_LAST_RESORT`, otherwise stop instead of creating a substitute surface.

## Default Flow

1. Select the Chrome-family binding (`agent.browsers.get("chrome")` on the current Codex Chrome skill), read its documentation, and verify the existing user-owned Chrome window/profile/session through tab discovery; foreground state is not required.
2. Use platform Chrome permission for the existing window when required by the plugin; do not treat the permission prompt as authorization to create another window.
3. After authorization, record the user's active tab and create a dedicated task tab in the same Chrome window/profile/session using the binding's documented API. Claim the exact created object. Reuse an existing tab only by explicit request.
4. Navigate, refresh, inspect, click, type, and verify in the dedicated task tab without interrupting the user's working tab. Prefer background creation and restore focus if the API temporarily activates the task tab.
5. Never create an alternate browser, profile, automation window, or unauthenticated session.

## User Prompts

Asking to open a site authorizes opening a tab in the existing Chrome window. A platform approval prompt may still appear for debugging control. Ask for additional help only when the user has not supplied a target and the target cannot be identified safely.

## Completion Rule

Once platform permission is granted, browser work is autonomous in the dedicated task tab of the user-owned Chrome window/profile/session.

## Bridge Recovery

A failed `mcp__node_repl__js` bootstrap or extension discovery call is a recoverable control-channel failure, not proof that Chrome or the user tab is unavailable.

1. Preserve any existing `agent`, `chrome`, browser, and tab bindings; never replace them with another browser surface.
2. Run one documented Chrome readiness/self-repair pass: retry the exact absolute-path `browser-client.mjs` bootstrap syntax from the installed Chrome skill, read `agent.documentation.get("bootstrap-troubleshooting")`, and for extension communication failures also read `agent.documentation.get("chrome-troubleshooting")`. Do not invent a `file:///` variant or switch to a directly exposed browser MCP.
3. Re-enumerate `user.openTabs()` and claim the exact matching returned object. A stale tab binding is recovered from the existing browser binding, not by reselecting or relaunching a browser.
4. If exact-object `claimTab()` reports that the tab belongs to another browser session, run the automatic tab-ownership recovery, reset the task browser binding, and reclaim the exact tab once. This is autonomous and does not require a coordinator or user action.
5. Reset the Node session only when the troubleshooting guidance identifies a corrupted session or the persistent bindings cannot be repaired. After reset, bootstrap the same extension surface again.
6. If the task's control channel remains degraded after that one readiness/self-repair pass, report stage/reason/next and seek a current `VERIFIED_HANDOFF` for the same dedicated task tab and current code state. Do not ask the user to acknowledge the handoff or run a visible retry loop.
7. If visual verification was requested, keep the task active until the dedicated task tab is claimed and verified locally or through the current handoff. Build, tests, or structural similarity cannot substitute for that gate.
8. Do not tell the user to restart Chrome unless Chrome or the extension is independently proven unavailable outside this task-local failure.
9. If control works and only `file://` navigation is rejected, keep the same
   dedicated tab and expose the artifact through a checked read-only
   `127.0.0.1` service. This is local navigation recovery, not a bridge failure,
   runtime-sync fix, alternate browser, or CDP justification. Report the
   stage/reason/next recovery to the user once.
