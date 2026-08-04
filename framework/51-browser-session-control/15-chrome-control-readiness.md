# Chrome Control Readiness Contract

Version: 1.0.0
Status: Mandatory for Chrome tasks

## Purpose

Chrome control failures must be resolved through a deterministic readiness path before any task reports that browser verification is unavailable. A task-local bridge failure, stale tab claim, permission prompt, minimized window, or missing screenshot is not enough to prove that Chrome cannot be used.

## Chrome Readiness Flow

Before using Chrome for navigation, inspection, screenshots, clicking, typing, upload, or authenticated verification, complete this Chrome readiness flow:

1. Read the installed Chrome `control-chrome/SKILL.md` and use its supported `browser-client.mjs` bootstrap through `mcp__node_repl__js`.
2. Select Chrome explicitly with `agent.browsers.get("chrome")` or the current skill-documented Chrome-family selector. Do not call `getDefault()`, `getForUrl()`, `get("iab")`, a directly exposed browser MCP, or a connector-created browser.
3. Read the selected Chrome binding documentation in full before using its tab API.
4. Enumerate `user.openTabs()` to prove the existing user-owned Chrome window/profile/session and record the active working tab. Do not claim or navigate that working tab by default.
5. Create one dedicated task tab through the documented API on the same Chrome binding. Verify that no window, profile, session, context, panel, or internal browser was created; prefer background creation and preserve the user's active tab.
6. Run `claimTab()` on the exact created tab object. Reuse an existing tab only when the user explicitly requested it. A platform permission prompt is normal authorization, not permission to create another surface.
7. If `claimTab()` reports a stale browser-session owner, run `scripts/repair-chrome-tab-ownership.ps1`, reset only the task tab binding, rebootstrap the same Chrome binding, and reclaim the exact dedicated tab once.
8. If the local bridge remains degraded after documented troubleshooting, classify it as `THREAD_CONTROL_CHANNEL_DEGRADED`, report the structured stage/reason/next diagnosis, automatically seek or accept a current `VERIFIED_HANDOFF` for the same dedicated tab and current code state, and continue non-browser work.
9. If no trusted coordinator channel can supply current same-target evidence, use verified visible Windows control only on Windows when the Chrome plugin itself is independently unavailable and the same user-owned window can be identified. On macOS/Linux skip visible control and continue only to an eligible authorized loopback stage.
10. If every configured prior stage has recorded failure evidence, report those stage/reason results and request or consume explicit authorization for emergency remote debugging. Run `scripts/get-remote-debugging-readiness.ps1 -AuthorizedLastResort -PriorStageFailure <recorded-stages> -ExpectedTargetId <dedicated-target-id>` and continue only on `READY_LAST_RESORT` with `sameTargetProven`. "Use the alternative" counts only when it unambiguously refers to this authorized emergency path; it never authorizes the in-app browser.
11. Attach to the same dedicated existing page target through loopback under `AUTHORIZED_LOOPBACK_LAST_RESORT`; never launch Chrome or inspect cookies/storage/profile data. Stricter host or skill rules still win.
12. Only report `CHROME_EXTERNALLY_UNAVAILABLE` when Chrome, the extension, every authorized same-window path, and any eligible authorized loopback fallback are independently proven unavailable.
13. Finalize the claimed task tab with `chrome.tabs.finalize(...)` before the turn ends unless an explicit handoff keeps it live; detach emergency CDP immediately after verification.

## Local Navigation Recovery

If the dedicated tab is controllable but browser policy rejects only a local
`file://` target, keep the control channel `READY`. Do not run runtime sync or
enter ownership/CDP recovery. Serve the same artifact through a verified
read-only `127.0.0.1` project service after checking documented ownership,
current listeners, and health. Report the local-navigation stage/reason/next
once, then continue verification in the same dedicated Chrome tab.

## Synthetic-Only Contingency

When all real-browser recovery paths fail, standalone Playwright may be offered
only after an explicit user request and only if the host permits it. It may test
a public or loopback page without personal session state and must be labeled
`SYNTHETIC_ONLY`. It cannot satisfy a same-profile, authenticated, existing-tab,
or visual Chrome gate and cannot bypass stricter host or installed-skill rules.

## Startup Order Hint

When the control channel fails before any `user.openTabs()` evidence exists, check and communicate the startup-order requirement before deeper recovery:

- Chrome or the required browser must already be open before Codex or the AI host starts a browser-control task.
- If Chrome was closed when Codex started, ask the user to open Chrome first, then restart Codex so the browser-control channel can bind to the existing browser session.
- This startup-order hint is allowed when the failure happens before tab discovery. It is not a claim that Chrome is broken, and it must not authorize a second browser, temporary profile, or isolated context.
- If Chrome was already open before Codex and the bridge still fails, continue the normal readiness, ownership repair, and `VERIFIED_HANDOFF` path.

## Non-Blocking Conditions

These conditions require readiness recovery or visual-evidence follow-up, not `BLOCKED`:

- The Chrome window is minimized, backgrounded, or not foreground.
- The tab has a supported platform debugging banner after extension attachment.
- A screenshot provider such as pCloud has not produced the final image yet.
- A task-local `mcp__node_repl__js`, browser-client, or extension bridge call failed.
- Another task left a stale browser-session ownership lock.

## Blocking Conditions

The task may ask for user action only when one of these is independently verified:

- No user-owned Chrome profile exists, or the Chrome binding cannot create a same-window dedicated task tab for the supplied target.
- The Chrome plugin/extension is unavailable and no verified visible Windows fallback can prove the same user-owned tab.
- The requested workflow requires authentication and the user-owned tab is not signed in.
- Chrome itself is closed or inaccessible outside the task-local bridge.

## Completion Rule

For browser-required work, completion requires local verification in the dedicated task tab or a current trusted `VERIFIED_HANDOFF` covering that same target and current code state. Build success, tests, source inspection, structural equivalence, or screenshot delay cannot replace that browser gate and cannot become a false `BLOCKED` state while meaningful work remains.
