# Browser Control Runtime Health

Distinguish a user-tab problem from a browser-control runtime problem before asking the user to change Chrome behavior.

## Diagnostic Order

1. Check that the supported Chrome extension is installed and enabled in the active profile.
2. Check that the native messaging host manifest is present and valid.
3. Initialize the supported browser-control runtime and perform one read-only tab-list attempt.
4. If the control runtime fails before tab discovery, report a control-runtime failure. Do not call it a missing tab, login, or user-browser failure.

## Recovery

- Do not repair the native host, modify browser profiles, or create alternate sessions from the agent.
- Ask the user to restart the Codex desktop application and retry the same existing Chrome tab first.
- If the failure persists after restart while extension and native-host checks pass, instruct the user to reinstall the ChatGPT Chrome Extension from the Codex plugin UI, then retry.
- Retain the user's open Chrome tabs and signed-in session throughout recovery.

## Communication

Say: "Chrome is ready, but Codex's browser-control channel did not start. Your open tabs and login are not the problem. Restart Codex and retry; I will use the same Chrome tab automatically."
