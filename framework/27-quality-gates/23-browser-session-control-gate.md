# Browser Session Control Gate

Version: 1.5.0  
Status: Release blocking for browser tasks

Pass only when the user's actually opened browser window and target tab are selected, window/profile identity is visibly verified, the visible domain and signed-in state are verified, no automation banner or isolated browser is present, no secrets or browser storage are inspected, final state is verified in the same tab, and browser status messages report a clear verified outcome without internal telemetry. A blank or wrong connector tab must trigger read-only tab discovery and user-tab reconnection guidance before blocking.

Fail when the assistant creates or switches to a new browser/context/profile without explicit approval, controls a connector-created Codex window, controls a window with an automation banner, treats a blank connector tab as the user's only browser without recovery, cannot prove active-window identity, assumes authentication, uses an unauthenticated result for an authenticated workflow, or continues after the user-owned browser is unavailable.
