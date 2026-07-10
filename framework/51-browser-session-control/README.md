# Browser Session Control

Version: 1.5.0  
Status: Release blocking for browser tasks

Browser work must use the browser and session the user actually opened. The assistant must not silently create an isolated browser, temporary profile, fresh context, or alternate login session.

## Mandatory Policy

- Select the existing user-owned browser surface first, using the available browser or Chrome connector that can see the user's real tabs and session.
- Confirm the target tab, visible domain, and signed-in state before reading or changing authenticated content.
- Do not inspect cookies, local storage, passwords, profiles, or session stores.
- If no user-owned browser/session is available, stop and ask the user to open the browser, target tab, and sign in.
- Use an isolated browser only after the user explicitly requests or approves it, and label it as not the user's active session.

## Related Modules

- framework/50-environment-bootstrap/06-uiux-profile.md
- framework/50-environment-bootstrap/12-mcp-detection.md
- framework/27-quality-gates/23-browser-session-control-gate.md
