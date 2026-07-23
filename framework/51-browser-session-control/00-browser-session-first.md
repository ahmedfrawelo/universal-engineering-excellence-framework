# Browser Session First

Before any browser navigation, clicking, typing, upload, download, or page inspection, identify the user's active browser surface and target tab. Browser selection is a precondition, not an implementation detail.

## Mandatory Browser Tool Gate

Before selecting or calling any browser tool for a user-owned Chrome task, run `scripts/get-ueef-task-preflight.ps1 -Task <task> -TaskTag browser` and resolve its `browserGate`. HARD FAIL BEFORE ANY BROWSER TOOL: when the gate is absent or unresolved, do not select a browser tool and do not create, launch, or switch to another surface. The allowed sequence is `mcp__node_repl__js` -> installed Chrome extension binding -> exact `user.openTabs()` object -> `claimTab()` -> claimed `tab.playwright` only.

- Prefer an existing user-owned tab and session.
- Do not call a default browser initializer that may create a new or isolated context when the task requires the user's login.
- Record browser surface, target tab, domain, and visible authentication state without inspecting secrets.
- Stop if the active user browser cannot be selected or verified.
- A connector-created Chrome surface is not proof of the user's visible window. The Chrome plugin extension binding plus `user.openTabs()` and `claimTab()` is proof when it attaches to the matching user-owned tab without creating a surface.
- Tool visibility is not surface identity. When a task depends on an existing user-owned Chrome session, visual verification, or authenticated site, direct Playwright, Chrome DevTools, `browser_*`, Cursor/IDE Simple Browser, in-app-browser MCP tools, `browser.newContext`, and `browser.launch` must not be selected as substitutes; bootstrap the installed Chrome plugin through `mcp__node_repl__js` instead. An isolated, local, or synthetic test requires an explicit separate user request; it must not access, perform, satisfy, or verify the user-owned Chrome task.
