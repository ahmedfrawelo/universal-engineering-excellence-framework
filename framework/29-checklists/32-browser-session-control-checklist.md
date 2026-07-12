# Browser Session Control Checklist

Version: 1.5.0

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
- [ ] No isolated browser/context/profile used silently.
- [ ] Explicit consent recorded if an isolated fallback was necessary.
- [ ] Final state verified in the same user-owned tab.
- [ ] Initial and final Chrome window state match unless the user explicitly requested a window change.

## Result

- Browser Session Gate: PASS / BLOCKED
- Missing user action:
- Browser surface and tab:
