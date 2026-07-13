# Browser Task Verification

Every browser task ends with evidence from the same user-owned browser session.

- Record the browser surface and target tab used.
- Verify the visible final state in that same tab.
- When the request requires browser or visual verification, do not report `COMPLETE` from source inspection, component reuse, build success, tests, or claimed structural equivalence. Keep the task active and recover the Chrome bridge until the required same-tab evidence exists. A current `VERIFIED_HANDOFF` from a trusted coordinator is valid same-tab evidence when it covers the current code state.
- Verify that the user's Chrome window state is unchanged unless resizing or window control was explicitly requested.
- Distinguish completed actions from blocked actions and authentication limitations.
- Never claim a logged-in workflow was completed from an isolated or unauthenticated context.
- A task-local `mcp__node_repl__js` failure is `THREAD_CONTROL_CHANNEL_DEGRADED`, not Chrome unavailability. It cannot justify `BLOCKED` or a user request to restart Chrome. Record and request a fresh cross-session handoff after relevant code changes.
- Do not surface local retry counts or a stopped-verification message. Use the required recovery status while the trusted handoff is obtained.
