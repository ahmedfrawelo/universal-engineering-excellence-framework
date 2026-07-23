# Browser Session Control Checklist

Version: 1.5.0

- [ ] `get-ueef-task-preflight.ps1 -TaskTag browser` produced `browserGate: REQUIRED` before any browser tool was selected.
- [ ] The gate's allowed path is `mcp__node_repl__js` -> extension binding -> exact `user.openTabs()` object -> `claimTab()` -> claimed `tab.playwright` only.
- [ ] If the gate could not be resolved, no browser tool or alternate surface was selected.
- [ ] User-owned browser surface selected.
- [ ] Chrome extension/tab-claim authorization was used for the existing user tab when Chrome control was needed.
- [ ] The target came from `user.openTabs()` and the exact returned object was passed to `claimTab()`.
- [ ] Debugging/CDP authorization was used only for debugging-specific capabilities.
- [ ] Visible Windows control was used only as fallback when the Chrome plugin was unavailable.
- [ ] Target tab selected by visible title, URL, and state.
- [ ] A user request to open a site opened a tab only in the existing Chrome window and profile.
- [ ] Target domain verified.
- [ ] Visible signed-in state verified without inspecting secrets.
- [ ] No cookies, passwords, tokens, local storage, or profile stores inspected.
- [ ] No isolated browser/context/profile used for the Chrome task.
- [ ] No directly exposed Playwright, Chrome DevTools, or in-app-browser MCP tool substituted for the Chrome plugin.
- [ ] Final state verified in the same user-owned tab.
- [ ] `chrome.tabs.finalize(...)` was the final browser action, releasing every claimed user tab without closing it.
- [ ] Any browser-client or extension bridge failure followed bootstrap and Chrome troubleshooting before fallback or blocking.
- [ ] A task-local Node REPL failure was not treated as Chrome unavailability; current coordinator evidence was handed off when needed.
- [ ] Required visual verification was not replaced by build/tests/source or structural-equivalence claims.
- [ ] Initial and final Chrome window state match unless the user explicitly requested a window change.

## Result

- Browser Session Gate: PASS / ACTIVE / BLOCKED
- Control channel: READY / THREAD_CONTROL_CHANNEL_DEGRADED
- Evidence source: LOCAL / VERIFIED_HANDOFF
- Missing user action:
- Browser surface and tab:
