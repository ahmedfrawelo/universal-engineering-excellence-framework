# Platform-Authorized Chrome Control

When a user asks to inspect, test, navigate, or operate a website, request access to the user's existing Chrome through the platform's official browser permission flow.

## Default Flow

1. Request the platform Chrome permission directly when control is needed.
2. If the platform displays an approval prompt, the user may choose its persistent approval option, such as `Always allow`, for future browser tasks.
3. After approval, discover and select the matching existing user tab automatically.
4. Navigate, refresh, inspect, click, type, and verify in that same tab without asking the user to repeat normal browser work.
5. Never create an alternate browser, profile, automation window, or unauthenticated session.

## User Prompts

The platform approval prompt is the only normal user action. Ask for additional help only when no matching user tab exists or the target cannot be identified safely.

## Completion Rule

Once platform permission is granted, browser work is autonomous in the selected user-owned Chrome tab.
