# Browser Session First

Before any browser navigation, clicking, typing, upload, download, or page inspection, identify the user's active browser surface and target tab. Browser selection is a precondition, not an implementation detail.

- Prefer an existing user-owned tab and session.
- Do not call a default browser initializer that may create a new or isolated context when the task requires the user's login.
- Record browser surface, target tab, domain, and visible authentication state without inspecting secrets.
- Stop if the active user browser cannot be selected or verified.
- A connector-created Chrome surface is not proof of the user's visible window. The Chrome plugin extension binding plus `user.openTabs()` and `claimTab()` is proof when it attaches to the matching user-owned tab without creating a surface.
- Tool visibility is not surface identity. When a task depends on an existing user-owned Chrome session, direct Playwright, Chrome DevTools, and in-app-browser MCP tools must not be selected as substitutes; bootstrap the installed Chrome plugin through `mcp__node_repl__js` instead. They remain valid for authorized isolated, local, or synthetic testing that does not depend on the user's session.
