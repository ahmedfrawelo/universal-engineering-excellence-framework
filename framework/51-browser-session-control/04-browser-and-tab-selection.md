# Browser and Tab Selection

Select the browser surface and tab using verified user-owned state; foreground visibility is not required.

- Verify the tab belongs to the user's existing browser window and profile, not a connector-created window or automation profile.
- Treat a separate automation window, newly launched automation process, temporary profile, or unrecognized profile as a failed identity check. A banner alone is not decisive when `user.openTabs()` and exact-object `claimTab()` prove attachment to the existing user tab.
- Discover tabs with `user.openTabs()` to prove the existing Chrome window/profile/session and record the user's active working tab without claiming or navigating it.
- By default, create one dedicated task tab through the already selected Chrome binding in the same existing window/profile/session, using only the tab-creation method documented by that binding. Pass the exact created tab object to `claimTab()`.
- Reuse an existing tab at the requested domain only when the user explicitly asks to use that tab. Otherwise, a matching tab is evidence of the correct session, not permission to take it over.
- If several tabs match, identify the target by title, URL, and visible state, then avoid unrelated tabs.
- Opening a site for a browser task authorizes one dedicated tab in the existing Chrome window/profile/session. It does not authorize a new window, browser, profile, session, context, panel, or in-app browser. Prefer background tab creation when supported and restore the user's previously active tab after any unavoidable focus change.
- Keep the selected browser binding and tab binding stable throughout the task; discard stale bindings only when the browser explicitly reports disconnection.
- If the extension cannot see a matching user tab or cannot prove tab/profile provenance, request that the user expose or connect the target tab; do not guess from a matching URL. Minimized or background state alone is not missing provenance.
