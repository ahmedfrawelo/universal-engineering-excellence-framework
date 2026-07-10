# Platform-Authorized Chrome Control

When a user asks to inspect, test, navigate, or operate a website, request access to the user's existing Chrome through the platform's official browser permission flow.

## Default Flow

1. Request the platform Chrome permission directly when control is needed.
2. If the platform displays an approval prompt, the user may choose its persistent approval option, such as `Always allow`, for future browser tasks.
3. After approval, discover and select the matching existing user tab automatically. If the user explicitly asks to open a site and no matching tab exists, open a new tab in that same Chrome window and profile.
4. Navigate, refresh, inspect, click, type, and verify in the selected or newly opened user-owned tab without asking the user to repeat normal browser work.
5. Never create an alternate browser, profile, automation window, or unauthenticated session.

## User Prompts

The platform approval prompt is the only normal user action. Asking to open a site authorizes opening a tab in the existing Chrome window. Ask for additional help only when the user has not supplied a target and the target cannot be identified safely.

## Completion Rule

Once platform permission is granted, browser work is autonomous in the selected or newly opened tab of the user-owned Chrome window.
