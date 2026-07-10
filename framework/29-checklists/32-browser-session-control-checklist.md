# Browser Session Control Checklist

Version: 1.5.0

- [ ] User-owned browser surface selected.
- [ ] Existing user tabs were discovered and the matching target was selected automatically before requesting user action.
- [ ] Target tab selected by visible title, URL, and state.
- [ ] Target domain verified.
- [ ] Visible signed-in state verified without inspecting secrets.
- [ ] No cookies, passwords, tokens, local storage, or profile stores inspected.
- [ ] No isolated browser/context/profile used silently.
- [ ] Explicit consent recorded if an isolated fallback was necessary.
- [ ] Final state verified in the same user-owned tab.
- [ ] A blank or wrong connector tab triggered tab discovery and user-tab recovery guidance before blocking.
- [ ] User-facing browser status uses a verified outcome and next action, without raw routes, screenshot events, or connector terminology.
- [ ] Extension/native-host/runtime health was distinguished from target-tab availability before asking the user to change Chrome behavior.

## Result

- Browser Session Gate: PASS / BLOCKED
- Missing user action:
- Browser surface and tab:
