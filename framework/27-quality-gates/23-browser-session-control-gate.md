# Browser Session Control Gate

Version: 1.5.0  
Status: Release blocking for browser tasks

Pass only when the Chrome readiness flow completed and the user's actual existing target is verified through the extension binding with the exact `user.openTabs()` object passed to `claimTab()`, trusted same-tab handoff, verified visible Windows control, or an explicitly authorized `AUTHORIZED_LOOPBACK_LAST_RESORT` that passed the readiness probe and attached to that same existing target. No route may create a browser/profile/context, inspect secrets or browser storage, or override stricter host/skill restrictions.

Fail when directly exposed Playwright, Chrome DevTools/CDP, or in-app-browser tools are used before their authorized stage; when emergency CDP lacks explicit user authorization, complete recorded prior-stage evidence, loopback-only readiness, or same-target proof; when the probe reports `PRIOR_STAGES_INCOMPLETE`; or when any route launches or switches browser/profile/context, inspects storage, assumes authentication, or controls an unverified automation window.

Do not fail because the claimed existing tab uses its in-plugin `tab.playwright` API, a verified extension binding is minimized/backgrounded, or an authorized emergency adapter attaches to the same existing loopback target under the stricter privacy contract.

A transient `mcp__node_repl__js`, browser-client bootstrap, or extension bridge failure requires the documented Chrome readiness recovery flow. A task-local failure is `THREAD_CONTROL_CHANNEL_DEGRADED`, not evidence that Chrome is unavailable, and it cannot justify `BLOCKED`, a user acknowledgement request, or asking the user to restart Chrome. Stale tab ownership must run automatic recovery before the deterministic same-tab control-channel failover: trusted `VERIFIED_HANDOFF`, then verified visible Windows control only when the plugin itself is unavailable. When visual verification is in scope, this gate cannot pass and the task cannot report `COMPLETE` until the exact user tab is claimed and verified, either locally or through a current trusted `VERIFIED_HANDOFF` that covers the same tab and current code state; build success, tests, source inspection, component reuse, and structural equivalence are not substitutes.
