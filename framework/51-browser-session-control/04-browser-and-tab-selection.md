# Browser and Tab Selection

Select the browser surface and tab using visible, user-owned state.

- Reuse an existing tab at the requested domain when available.
- If several tabs match, identify the target by title, URL, and visible state, then avoid unrelated tabs.
- Do not open a new tab unless the user asked for it or the current browser surface requires it and the action is reversible.
- Keep the selected browser binding and tab binding stable throughout the task; discard stale bindings only when the browser explicitly reports disconnection.
