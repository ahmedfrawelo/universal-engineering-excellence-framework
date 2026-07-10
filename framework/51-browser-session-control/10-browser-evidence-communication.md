# Browser Evidence Communication

Browser status messages are user-facing product communication, not tool telemetry.

## Required Rules

- State the verified outcome in the user's language: what changed, where it changed, and whether it was visually confirmed.
- Mention a route, URL fragment, screenshot, connector, tab ID, browser API, or internal tool only when it is necessary for the user to act.
- Never mix an internal event label with an incomplete sentence such as "screenshot updated", "refresh after /path", or "waiting for screenshot".
- Do not claim a refresh, visual confirmation, login state, or interaction result until the matching user-owned tab has been verified.
- If visual verification is pending, say exactly what is pending and the one action required, without tool jargon.

## Preferred Status Shapes

- Confirmed: "The page is open in your Chrome tab and the update is visible."
- Pending connection: "Your target tab is open, but it is not connected yet. Connect that same tab, then tell me it is ready."
- Pending verification: "The change was sent. I still need to verify it in your open tab before I confirm completion."
- Blocked: "I cannot verify the page because the connection is attached to a different tab. I have not opened another browser."

## Failure Rule

Fail browser-task communication when it exposes unexplained internal paths, screenshots, routes, or tool states instead of a clear user outcome and next action.
