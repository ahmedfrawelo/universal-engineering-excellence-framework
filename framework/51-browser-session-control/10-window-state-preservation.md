# User Browser Window State Preservation

Browser automation must preserve the user's visible Chrome window state.

## Required Rules

- Treat the current window size, maximized/full-screen state, monitor placement, zoom, tab order, and active tab as user-owned state.
- Do not call resize, viewport emulation, maximize, minimize, restore, move-window, or full-screen controls on the user's Chrome window unless the user explicitly requests that action.
- Use screenshots, DOM snapshots, and responsive CSS inspection instead of changing the user's browser dimensions for visual testing.
- If the browser-control platform changes the window state unexpectedly, restore the original visible state before reporting completion.
- Open user-requested sites in a new tab of the existing window, never in a new fixed-size Chrome window.

## Verification

Record the initial and final window state for browser tasks. A task fails its browser-session verification if the user's maximized/full-screen browser is left restored, resized, moved, minimized, or otherwise changed without explicit request.
