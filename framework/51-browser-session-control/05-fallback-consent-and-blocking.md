# Fallback Consent and Blocking

Missing access is a blocking state, not permission to improvise a new session.

- Automatically search existing user tabs before asking the user to open or navigate anything. Ask only when no usable matching tab is available to the connector.
- Ask for explicit approval before using an isolated browser, alternate profile, or unauthenticated fallback.
- Do not ask the user to share credentials or session secrets.
- Report exactly what is missing, what the user must do, and what will happen after the session is ready.
- Do not recover by opening a connector-created Chrome window. Reacquire a fresh tab from the existing Chrome extension binding; use visible Windows control only if the plugin is unavailable and the user's current window is identified.
