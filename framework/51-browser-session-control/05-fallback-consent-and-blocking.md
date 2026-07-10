# Fallback Consent and Blocking

Missing access is a blocking state, not permission to improvise a new session.

- Ask the user to open the required browser, target tab, and signed-in account when no usable session is available.
- Ask for explicit approval before using an isolated browser, alternate profile, or unauthenticated fallback.
- Do not ask the user to share credentials or session secrets.
- Report exactly what is missing, what the user must do, and what will happen after the session is ready.
- Do not recover by opening a connector-created Chrome window; use visible Windows control only after the user's current window is identified.
