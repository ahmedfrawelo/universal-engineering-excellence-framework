# Browser Session Control

Version: 1.5.0  
Status: Release blocking for browser tasks

Browser work must use the browser and session the user actually opened. The assistant must not silently create an isolated browser, temporary profile, fresh context, or alternate login session.


## Mandatory Policy

- For Chrome, use only the installed Chrome plugin skill through `mcp__node_repl__js`, its extension binding, and exact-object tab claim.
- Confirm the target tab, visible domain, and signed-in state before reading or changing authenticated content.
- Do not inspect cookies, local storage, passwords, profiles, or session stores.
- If no user-owned browser/session is available, stop and ask the user to open the browser, target tab, and sign in.
- Never use an isolated browser to perform or verify a Chrome task. A separately requested isolated test is a distinct task and result.

## Related Modules

- framework/50-environment-bootstrap/06-uiux-profile.md
- framework/50-environment-bootstrap/12-mcp-detection.md
- framework/27-quality-gates/23-browser-session-control-gate.md
