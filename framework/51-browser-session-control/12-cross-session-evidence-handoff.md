# Cross-Session Browser Evidence Handoff

## Purpose

A task-local `mcp__node_repl__js` failure is a degraded control channel, not evidence that Chrome, the extension, or the user-owned tab is unavailable. A trusted coordinator session may provide browser evidence to the affected task without opening a new browser surface.

## Classification

- `THREAD_CONTROL_CHANNEL_DEGRADED`: the task's Node REPL or browser client fails, while Chrome availability is unproven.
- `CHROME_EXTERNALLY_UNAVAILABLE`: the installed plugin or extension is independently confirmed unavailable after the documented recovery flow. This is the only browser-related basis for asking the user to repair or restart Chrome.
- `VERIFIED_HANDOFF`: a trusted coordinator used the installed Chrome skill, `user.openTabs()`, and exact-object `claimTab()` on the existing user-owned tab and recorded current evidence.

Never infer `CHROME_EXTERNALLY_UNAVAILABLE` from `THREAD_CONTROL_CHANNEL_DEGRADED`. Do not mark the task `BLOCKED`, ask the user to restart Chrome, or say live Chrome is unavailable on that inference alone.

After the first task-local bridge failure, request the handoff instead of retrying and narrating failures to the user. The user-facing recovery protocol governs the only permitted interim status.

## Handoff Record

The coordinator records, in the receiving task, the verified URL, visible title or state, exact tab identity, verification time, evidence type (screenshot, DOM, and/or fresh console result), and the code state or change boundary it covers. The receiving task may use the record only when it covers its current code state and exact target tab.

If the receiving task changes relevant code after the handoff, it stays active and requests a fresh same-tab verification. A stale handoff never permits `COMPLETE`; it also never creates a reason to block or ask the user to restart Chrome.

## Gate Rule

For browser or visual work, a current `VERIFIED_HANDOFF` satisfies the same-tab verification gate. The task must report the handoff as evidence, not as its own successful local control call. This preserves the user's existing browser, avoids an alternate surface, and prevents a thread-scoped transport fault from stopping engineering work.
