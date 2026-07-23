# Fallback Consent and Blocking

Missing access is a blocking state, not permission to improvise a new session. A failed control channel must first use the deterministic same-tab failover path; it is never a reason to wait for a user acknowledgement.

- Automatically search existing user tabs before asking the user to open or navigate anything. Ask only when no usable matching tab is available to the connector.
- Do not use an isolated browser, alternate profile, or unauthenticated session as a recovery fallback. A separately requested isolated test is a different task.
- Do not ask the user to share credentials or session secrets.
- Report exactly what is missing, what the user must do, and what will happen after the session is ready.
- Do not recover by opening a connector-created Chrome window. Reacquire a fresh tab from the existing Chrome extension binding; use visible Windows control only on Windows if the plugin is unavailable and the user's current window is identified. On macOS/Linux, stop and ask for the existing tab rather than switching surfaces.
- When the local extension channel remains degraded, automatically seek a trusted same-tab `VERIFIED_HANDOFF`; no user message such as a confirmation, acknowledgement, or "done" is part of this path.
