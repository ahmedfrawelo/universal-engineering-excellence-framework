# Platform-Authorized Chrome Control

When a user asks to inspect, test, navigate, or operate a website in Chrome, use the Chrome plugin extension binding to enumerate and claim the verified user-owned tab. Claiming an existing tab is ordinary Chrome control, not creation of a debugging browser. Use visible Windows control only if the plugin is unavailable.

## Default Flow

1. Verify the visible active Chrome window and use visible control for ordinary interaction.
2. Use platform Chrome permission for the existing window when required by the plugin; do not treat the permission prompt as authorization to create another window.
3. After authorization, discover and select the matching existing user tab automatically. If the user explicitly asks to open a site and no matching tab exists, open a new tab in that same Chrome window and profile.
4. Navigate, refresh, inspect, click, type, and verify in the selected or newly opened user-owned tab without asking the user to repeat normal browser work.
5. Never create an alternate browser, profile, automation window, or unauthenticated session.

## User Prompts

Asking to open a site authorizes opening a tab in the existing Chrome window. A platform approval prompt may still appear for debugging control. Ask for additional help only when the user has not supplied a target and the target cannot be identified safely.

## Completion Rule

Once platform permission is granted, browser work is autonomous in the selected or newly opened tab of the user-owned Chrome window.
