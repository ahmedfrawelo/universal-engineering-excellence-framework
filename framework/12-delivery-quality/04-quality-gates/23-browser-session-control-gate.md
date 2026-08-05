# Browser Session Control Gate

Version: 1.5.0  
Status: Release blocking for browser tasks

Pass only when the Chrome readiness flow explicitly selected the Chrome-family binding, proved the existing window/profile/session through `user.openTabs()`, created a dedicated task tab in that same binding, preserved the user's working tab, and claimed the exact created object. Reusing an existing user tab requires an explicit request. A trusted same-target handoff, verified visible Windows control, or explicitly authorized `AUTHORIZED_LOOPBACK_LAST_RESORT` may continue only against that same dedicated target. No route may create another window/browser/profile/session/context/panel, use the in-app browser, inspect secrets or browser storage, or override stricter host/skill restrictions.

Fail when a default/URL/in-app selector is used for the Chrome task; when the user's working tab is taken over without explicit permission; when directly exposed Playwright, Chrome DevTools/CDP, or in-app-browser tools are used before their authorized stage; when a failure is reported without stage/reason/next; when emergency CDP lacks authorization and prior-stage evidence; or when any route creates or switches window/browser/profile/session/context/panel.

Do not fail because the claimed existing tab uses its in-plugin `tab.playwright` API, a verified extension binding is minimized/backgrounded, or an authorized emergency adapter attaches to the same existing loopback target under the stricter privacy contract.

A transient browser-client or Chrome bridge failure requires the documented readiness recovery flow and a structured stage/reason/next report. It cannot justify `BLOCKED` or switching to the in-app browser. Stale task-tab ownership must run automatic recovery before deterministic same-target failover. When visual verification is in scope, this gate cannot pass until the dedicated task tab is verified locally or through a current `VERIFIED_HANDOFF` covering that target and current code state.
