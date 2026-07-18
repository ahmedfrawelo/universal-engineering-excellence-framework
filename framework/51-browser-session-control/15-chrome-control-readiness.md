# Chrome Control Readiness Contract

Version: 1.0.0
Status: Mandatory for Chrome tasks

## Purpose

Chrome control failures must be resolved through a deterministic readiness path before any task reports that browser verification is unavailable. A task-local bridge failure, stale tab claim, permission prompt, minimized window, or missing screenshot is not enough to prove that Chrome cannot be used.

## Chrome Readiness Flow

Before using Chrome for navigation, inspection, screenshots, clicking, typing, upload, or authenticated verification, complete this Chrome readiness flow:

1. Read the installed Chrome `control-chrome/SKILL.md` and use its supported `browser-client.mjs` bootstrap through `mcp__node_repl__js`.
2. Select the Chrome plugin extension binding, not a directly exposed browser MCP and not a connector-created browser.
3. Enumerate `user.openTabs()` and select the exact returned object for the user-owned tab. Do not reconstruct the tab from URL text.
4. Run `claimTab()` on that exact object. A platform permission prompt is normal authorization, not a failure and not permission to create another browser profile.
5. If `claimTab()` reports a stale browser-session owner, run `scripts/repair-chrome-tab-ownership.ps1`, reset the task browser binding, rebootstrap the same extension binding, and reclaim the exact tab once.
6. If the local bridge is still degraded after documented bootstrap troubleshooting, classify it as `THREAD_CONTROL_CHANNEL_DEGRADED`, automatically seek or accept a current `VERIFIED_HANDOFF` for the same tab and current code state, and continue non-browser work. Do not ask the user to acknowledge, confirm, or type "done" to begin this failover.
7. If no trusted coordinator channel can supply current same-tab evidence, use verified visible Windows control only when the Chrome plugin itself is independently unavailable and the same user-owned window can be identified. Do not create a browser, profile, or isolated context.
8. Only report `CHROME_EXTERNALLY_UNAVAILABLE` when Chrome, the extension, and every authorized same-window control path are independently proven unavailable outside the task-local control channel.
9. Finalize claimed tabs with `chrome.tabs.finalize(...)` before the turn ends unless an explicit handoff keeps the tab live for the next task.

## Non-Blocking Conditions

These conditions require readiness recovery or visual-evidence follow-up, not `BLOCKED`:

- The Chrome window is minimized, backgrounded, or not foreground.
- The tab has a supported platform debugging banner after extension attachment.
- A screenshot provider such as pCloud has not produced the final image yet.
- A task-local `mcp__node_repl__js`, browser-client, or extension bridge call failed.
- Another task left a stale browser-session ownership lock.

## Blocking Conditions

The task may ask for user action only when one of these is independently verified:

- No user-owned Chrome profile or target tab exists and the user did not provide a target to open.
- The Chrome plugin/extension is unavailable and no verified visible Windows fallback can prove the same user-owned tab.
- The requested workflow requires authentication and the user-owned tab is not signed in.
- Chrome itself is closed or inaccessible outside the task-local bridge.

## Completion Rule

For browser-required work, completion requires either local same-tab verification or a current trusted `VERIFIED_HANDOFF` that covers the same user-owned tab and current code state. Build success, tests, source inspection, structural equivalence, or screenshot delay cannot replace that browser gate, and cannot become a false `BLOCKED` state while meaningful implementation or non-visual verification can continue.
