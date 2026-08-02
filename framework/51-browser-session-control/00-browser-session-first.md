# Browser Session First

Before any browser navigation, clicking, typing, upload, download, or page inspection, identify the user's active Chrome surface and establish a task-owned tab policy. Browser selection is a precondition, not an implementation detail.

## Mandatory Browser Tool Gate

Before selecting or calling any browser tool for a user-owned Chrome task, run `scripts/get-ueef-task-preflight.ps1 -Task <task> -TaskTag browser` and resolve its `browserGate`. HARD FAIL BEFORE ANY BROWSER TOOL: when the gate is absent or unresolved, do not select a browser tool and do not create, launch, or switch to another surface. The allowed sequence is the installed Chrome skill -> `agent.browsers.get("chrome")` or the skill-documented Chrome-family selector -> full browser documentation -> prove the existing user window/profile with `user.openTabs()` -> create a dedicated task tab through that same Chrome binding -> pass the exact created object to `claimTab()` -> claimed `tab.playwright` only. Reuse an existing user tab only when the user explicitly requests that tab.

Run `scripts/test-browser-control-contract.ps1` (or `.sh` on Unix) as the local browser-enforcement smoke: it rejects `browser.launch`, IDE/in-app browser surfaces, and directly exposed browser MCP substitutions while preserving the allowed sequence above.

- Prefer a dedicated task tab in the existing user-owned Chrome window, profile, and signed-in session. Do not navigate, claim, or take focus from the user's working tab by default.
- Do not call a default browser initializer that may create a new or isolated context when the task requires the user's login.
- Record browser surface, target tab, domain, and visible authentication state without inspecting secrets.
- Stop if the active user browser cannot be selected or verified.
- A connector-created Chrome surface is not proof of the user's visible window. The Chrome-family binding plus `user.openTabs()` proves the existing user-owned window/profile; the task then creates and claims its own tab in that binding without creating a window, profile, session, context, panel, or internal-browser surface.
- Tool visibility is not surface identity. When a task depends on an existing user-owned Chrome session, visual verification, or authenticated site, direct Playwright, Chrome DevTools, `browser_*`, Cursor/IDE Simple Browser, in-app-browser MCP tools, `browser.newContext`, and `browser.launch` must not be selected as substitutes; bootstrap the installed Chrome plugin through `mcp__node_repl__js` instead. An isolated, local, or synthetic test requires an explicit separate user request; it must not access, perform, satisfy, or verify the user-owned Chrome task.
