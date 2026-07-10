# Browser and Tab Selection

Select the browser surface and tab using visible, user-owned state.

- Verify the tab belongs to the user's currently visible browser window, not a connector-created window or automation profile.
- Treat a visible `Chrome is being controlled by automated test software` banner, a separate automation window, or an unrecognized profile as a failed window-identity check.
- Reuse an existing tab at the requested domain when available.
- If several tabs match, identify the target by title, URL, and visible state, then avoid unrelated tabs.
- Do not open a new tab unless the user asked for it or the current browser surface requires it and the action is reversible.
- Keep the selected browser binding and tab binding stable throughout the task; discard stale bindings only when the browser explicitly reports disconnection.
- If the connector cannot prove the active window identity, stop and request the user to expose the target window; do not guess from a matching URL.
