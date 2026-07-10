# Browser Session Control Checklist

Version: 1.5.0

- [ ] User-owned browser surface selected.
- [ ] Official platform Chrome permission was requested when browser control was needed.
- [ ] Visible Windows control was preferred for ordinary navigation and interaction; debugging control was selected only for debugging-specific needs.
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
