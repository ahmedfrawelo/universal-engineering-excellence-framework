# Fallback Consent and Blocking

Missing access is not permission to improvise a new session. A failed control channel must use deterministic same-target failover for the dedicated task tab.

- Automatically prove the existing Chrome window/profile/session, then create a dedicated task tab through that binding. Ask only when Chrome or same-window tab creation is independently unavailable.
- Do not use an isolated browser, alternate profile, or unauthenticated session as a recovery fallback. A separately requested isolated test is a different task.
- Do not ask the user to share credentials or session secrets.
- Report the failed stage, a human-readable reason category, the evidence observed, and the next allowed action. Do not repeat a generic "connection/channel failed" message and do not expose raw stack traces, secrets, cookies, storage, or retry counts.
- Do not recover by opening a connector-created Chrome window. Reacquire a fresh tab from the existing Chrome extension binding; use visible Windows control only on Windows if the plugin is unavailable and the user's current window is identified. On macOS/Linux skip visible control and continue only to an eligible authorized loopback stage; otherwise stop and ask for the existing tab.
- When the local Chrome channel remains degraded, automatically seek a trusted `VERIFIED_HANDOFF` for the same dedicated task tab; no user acknowledgement is required for that internal handoff.
- After the Chrome binding, troubleshooting, ownership repair, trusted same-target handoff, and verified visible Windows stage have all failed, the user may explicitly authorize `AUTHORIZED_LOOPBACK_LAST_RESORT`. It attaches through the already-enabled loopback debugging endpoint to the same dedicated existing target only; it cannot launch Chrome, create a profile/context, bind a network interface, or inspect cookies, storage, passwords, or profile files. If the host or installed browser skill prohibits a direct CDP adapter, that prohibition wins and this stage remains unavailable.
- After the prior-stage evidence exists, an unambiguous instruction such as "use the emergency fallback" or "use the authorized alternative" counts as authorization for `AUTHORIZED_LOOPBACK_LAST_RESORT` only. It never authorizes the in-app browser, another browser, another window, or another session.
