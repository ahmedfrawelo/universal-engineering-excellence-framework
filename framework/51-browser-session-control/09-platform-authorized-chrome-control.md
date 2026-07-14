# Platform-Authorized Chrome Control

When a user asks to inspect, test, navigate, or operate a website in Chrome, use the Chrome plugin extension binding to enumerate and claim the verified user-owned tab. Claiming an existing tab is ordinary Chrome control, not creation of a debugging browser. Use visible Windows control only if the plugin is unavailable.

## Default Flow

1. Verify the existing user-owned Chrome tab through extension discovery and exact-object claim; foreground or restored window state is not required.
2. Use platform Chrome permission for the existing window when required by the plugin; do not treat the permission prompt as authorization to create another window.
3. After authorization, discover and select the matching existing user tab automatically. If the user explicitly asks to open a site and no matching tab exists, open a new tab in that same Chrome window and profile.
4. Navigate, refresh, inspect, click, type, and verify in the selected or newly opened user-owned tab without asking the user to repeat normal browser work.
5. Never create an alternate browser, profile, automation window, or unauthenticated session.

## User Prompts

Asking to open a site authorizes opening a tab in the existing Chrome window. A platform approval prompt may still appear for debugging control. Ask for additional help only when the user has not supplied a target and the target cannot be identified safely.

## Completion Rule

Once platform permission is granted, browser work is autonomous in the selected or newly opened tab of the user-owned Chrome window.

## Bridge Recovery

A failed `mcp__node_repl__js` bootstrap or extension discovery call is a recoverable control-channel failure, not proof that Chrome or the user tab is unavailable.

1. Preserve any existing `agent`, `chrome`, browser, and tab bindings; never replace them with another browser surface.
2. Retry the exact absolute-path `browser-client.mjs` bootstrap syntax from the installed Chrome skill. Do not invent a `file:///` variant or switch to a directly exposed browser MCP.
3. When the runtime is available, read `agent.documentation.get("bootstrap-troubleshooting")`; for extension communication failures also read `agent.documentation.get("chrome-troubleshooting")`, then apply the documented recovery.
4. Re-enumerate `user.openTabs()` and claim the exact matching returned object. A stale tab binding is recovered from the existing browser binding, not by reselecting or relaunching a browser.
5. Reset the Node session only when the troubleshooting guidance identifies a corrupted session or the persistent bindings cannot be repaired. After reset, bootstrap the same extension surface again.
6. If visual verification was requested, keep the task active until the same user-owned tab is claimed and verified. Build, tests, or structural similarity cannot substitute for that gate.
7. If the task's control channel remains degraded but a trusted coordinator can claim the same user-owned tab, request and record a `VERIFIED_HANDOFF`. Do not tell the user to restart Chrome unless Chrome or the extension is independently proven unavailable outside this task-local failure.
8. If exact-object `claimTab()` reports that the tab belongs to another browser session, run the automatic tab-ownership recovery, reset the task browser binding, and reclaim the exact tab once. This is autonomous and does not require a coordinator or user action.
