# Autonomous User Tab Control

When the user asks the agent to open, inspect, test, or operate a site, the default is autonomous control of the user's existing Chrome tabs.

## Default Behavior

1. Use the available Chrome connector to discover existing user tabs automatically.
2. Match the target by the requested URL, title, domain, or visible page state.
3. Select and control the matching tab without asking the user to repeat navigation, refresh, click, or login steps that are already available in that tab.
4. Keep using that same tab for inspection, interaction, screenshots, and verification.
5. Never open a parallel browser/profile/context just because the first connector result is blank or stale.

## When User Action Is Actually Required

Ask only when the connector cannot see any matching user tab, the requested tab is not connected/exposed to the connector, or the target identity is ambiguous between unrelated tabs. Explain the single required action: expose or connect the already open target tab. Do not turn normal browser navigation into a manual user workflow.

## Completion Rule

For an accessible user-owned tab, the agent must navigate, inspect, click, type, wait, and verify autonomously. A user prompt is a connector-capability exception, not the default interaction model.
