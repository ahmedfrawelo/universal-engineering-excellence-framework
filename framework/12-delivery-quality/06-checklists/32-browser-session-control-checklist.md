# Browser Session Control Checklist

Version: 1.5.0

- [ ] `get-ueef-task-preflight.ps1 -TaskTag browser` produced `browserGate: REQUIRED` before any browser tool was selected.
- [ ] The gate's allowed path explicitly selects Chrome, reads its documentation, proves the existing window/profile/session with `user.openTabs()`, creates a dedicated task tab in that same binding, claims the exact created object, and uses only its `tab.playwright` API.
- [ ] If the gate could not be resolved, no browser tool or alternate surface was selected.
- [ ] Emergency CDP, if used, was explicitly user-authorized only after every configured prior stage had recorded failure evidence; the probe received all `-PriorStageFailure` values plus `-ExpectedTargetId` for the dedicated tab and returned `READY_LAST_RESORT` rather than `PRIOR_STAGES_INCOMPLETE`, endpoint/browser/target sockets were loopback-only WebSockets, `sameTargetProven` was true, no browser/profile/context was launched, and cookies/storage/password/profile/history APIs were not used.
- [ ] User-owned browser surface selected.
- [ ] The user's active working tab was recorded and not claimed or navigated without explicit permission.
- [ ] A dedicated task tab was created in the same Chrome window/profile/session and its exact returned object was passed to `claimTab()`.
- [ ] Debugging/CDP authorization was used only for debugging-specific capabilities.
- [ ] Visible Windows control was used only as fallback when the Chrome plugin was unavailable.
- [ ] Target tab selected by visible title, URL, and state.
- [ ] No new window, browser, profile, session, context, panel, or in-app browser was created.
- [ ] Target domain verified.
- [ ] Visible signed-in state verified without inspecting secrets.
- [ ] No cookies, passwords, tokens, local storage, or profile stores inspected.
- [ ] No isolated browser/context/profile used for the Chrome task.
- [ ] No directly exposed Playwright, Chrome DevTools, or in-app-browser MCP tool substituted for the Chrome plugin.
- [ ] Final state verified in the dedicated task tab inside the existing Chrome window/profile/session.
- [ ] `chrome.tabs.finalize(...)` was the final browser action, releasing every claimed user tab without closing it.
- [ ] Every browser-control failure reported its stage, human-readable reason/evidence, and next allowed action; no generic repeated channel-failure status was used.
- [ ] After all prior stages failed, emergency authorization was requested or consumed explicitly; "alternative" never selected the in-app browser.
- [ ] A task-local Node REPL failure was not treated as Chrome unavailability; current coordinator evidence was handed off when needed.
- [ ] Required visual verification was not replaced by build/tests/source or structural-equivalence claims.
- [ ] Initial and final Chrome window state match unless the user explicitly requested a window change.

## Result

- Browser Session Gate: PASS / ACTIVE / BLOCKED
- Control channel: READY / THREAD_CONTROL_CHANNEL_DEGRADED
- Evidence source: LOCAL / VERIFIED_HANDOFF
- Missing user action:
- Browser surface and tab:
