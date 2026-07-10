# User Browser Connection Recovery

Use this procedure when a Chrome connector reports a blank page, an empty tab list, an unverified tab, or a browser surface that is not visibly the user's intended tab.

## Required Recovery Order

1. Do not open a new browser, profile, incognito window, automation context, or alternate login.
2. Reuse the existing Chrome connector and discover its available tabs read-only.
3. Select only a tab whose visible title, URL, and user-visible state match the requested target.
4. If the connector is attached only to a blank or wrong tab, report that exact mismatch and ask the user to connect the existing target tab through the browser's approved connection control, then confirm when it is connected.
5. Re-discover tabs and verify the active target before any interaction.

## User-Facing Instruction

Say: "The connection is currently attached to a blank or different tab. In the Chrome window you are already using, open the target page and use the approved Codex/Chrome connection control for that tab. Keep the same signed-in profile open, then tell me it is connected. I will not open another browser."

Do not claim a visual check, login state, or browser control capability until the connector exposes the matching tab.

## Failure Conditions

- Treat a blank connector page as evidence of a wrong attachment, not evidence that the user has no open browser.
- Never ask the user to sign in again before proving the target tab is unavailable.
- Never replace the target with a connector-created window.
- If the approved connection control is unavailable, report the missing capability and leave the user's browser unchanged.
