# Browser Session Control Checklist

Version: 1.5.0

- [ ] User-owned browser surface selected.
- [ ] Official platform Chrome permission was requested when browser control was needed.
- [ ] Target tab selected by visible title, URL, and state.
- [ ] Target domain verified.
- [ ] Visible signed-in state verified without inspecting secrets.
- [ ] No cookies, passwords, tokens, local storage, or profile stores inspected.
- [ ] No isolated browser/context/profile used silently.
- [ ] Explicit consent recorded if an isolated fallback was necessary.
- [ ] Final state verified in the same user-owned tab.

## Result

- Browser Session Gate: PASS / BLOCKED
- Missing user action:
- Browser surface and tab:
