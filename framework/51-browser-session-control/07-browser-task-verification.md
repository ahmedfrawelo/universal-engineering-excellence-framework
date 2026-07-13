# Browser Task Verification

Every browser task ends with evidence from the same user-owned browser session.

- Record the browser surface and target tab used.
- Verify the visible final state in that same tab.
- When the request requires browser or visual verification, do not report `COMPLETE` from source inspection, component reuse, build success, tests, or claimed structural equivalence. Keep the task active and recover the Chrome bridge until the required same-tab evidence exists.
- Verify that the user's Chrome window state is unchanged unless resizing or window control was explicitly requested.
- Distinguish completed actions from blocked actions and authentication limitations.
- Never claim a logged-in workflow was completed from an isolated or unauthenticated context.
