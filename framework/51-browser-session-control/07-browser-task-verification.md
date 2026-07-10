# Browser Task Verification

Every browser task ends with evidence from the same user-owned browser session.

- Record the browser surface and target tab used.
- Verify the visible final state in that same tab.
- Verify that the user's Chrome window state is unchanged unless resizing or window control was explicitly requested.
- Distinguish completed actions from blocked actions and authentication limitations.
- Never claim a logged-in workflow was completed from an isolated or unauthenticated context.
