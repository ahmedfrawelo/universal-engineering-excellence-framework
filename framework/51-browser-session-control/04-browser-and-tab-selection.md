# Browser and Tab Selection

Select the browser surface and tab using visible, user-owned state.

- Verify the tab belongs to the user's currently visible browser window, not a connector-created window or automation profile.
- Treat a separate automation window, newly launched automation process, temporary profile, or unrecognized profile as a failed identity check. A banner alone is not decisive when `user.openTabs()` and exact-object `claimTab()` prove attachment to the existing user tab.
- Reuse an existing tab at the requested domain when available.
- Discover tabs with `user.openTabs()`, match visible title, URL, recency, and state, then pass that exact returned object to `claimTab()` before asking the user to navigate or refresh.
- If several tabs match, identify the target by title, URL, and visible state, then avoid unrelated tabs.
- Do not open a new tab unless the user asked for it or the current browser surface requires it and the action is reversible.
- Keep the selected browser binding and tab binding stable throughout the task; discard stale bindings only when the browser explicitly reports disconnection.
- If the connector cannot see a matching tab or cannot prove active-window identity, request that the user expose or connect the target tab; do not guess from a matching URL.
