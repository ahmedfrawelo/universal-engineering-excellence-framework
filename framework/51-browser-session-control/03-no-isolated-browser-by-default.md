# No Isolated Browser by Default

An isolated browser is prohibited for user-session tasks unless the user explicitly approves it.

- Do not launch a new browser or context to bypass missing access.
- Do not use a fresh context to claim the user's work is complete.
- Isolated contexts are acceptable for public, unauthenticated, deterministic tests only when they do not replace the user's requested session.
- Label isolated results as separate from the user's active browser and never merge their authentication assumptions.
- A Codex-titled connector window, visible automation banner, or unrecognized profile is treated as an unusable user browser and must be blocked.
