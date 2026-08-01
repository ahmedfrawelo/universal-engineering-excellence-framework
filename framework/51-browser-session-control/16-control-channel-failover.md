# Same-Tab Control-Channel Failover

## Purpose

Browser verification must survive a task-local transport failure without asking the user to repeat setup, acknowledge a transfer, or accept a different browser. Failover changes the control channel, never the user's Chrome window, profile, signed-in session, or target tab.

## Automatic Failover Order

1. Reuse the existing Chrome extension binding and exact user-owned tab.
2. Run the documented readiness troubleshooting and automatic stale-ownership repair once.
3. Automatically seek a current `VERIFIED_HANDOFF` from a trusted coordinator that can claim the same user-owned tab and cover the current code state.
4. If the Chrome plugin itself is independently unavailable, use verified visible Windows control for that same user-owned window only on Windows. On macOS/Linux skip this stage and continue only to an eligible authorized loopback stage; never create a substitute surface.
5. If every prior stage is independently unavailable with recorded failure evidence and the user explicitly authorized it, use `AUTHORIZED_LOOPBACK_LAST_RESORT` only after the readiness script receives every configured `-PriorStageFailure` and returns `READY_LAST_RESORT`; `PRIOR_STAGES_INCOMPLETE` cannot pass. Attach to the same existing target without launch, storage inspection, or non-loopback exposure. Stricter host or installed-skill rules still win.
6. Ask the user for action only after every authorized same-window path and eligible emergency stage are independently unavailable, and state the externally verified missing condition.

## Invariants

- Automatic failover never creates a Chrome window, temporary profile, isolated context, or unsigned-in session.
- No user acknowledgement, confirmation, "done" message, tab re-share, or restart request is required to move between failover stages.
- A trusted handoff is evidence from the same tab, not permission to infer a result from another page or browser.
- Preserve window geometry, monitor placement, zoom, tab order, active tab, route, scroll, focus, filters, selection, and unsaved edits.
- A failed coordinator channel is `THREAD_CONTROL_CHANNEL_DEGRADED`, not proof that Chrome is unavailable. Continue implementation and non-browser validation while another same-window channel is sought.
- Emergency CDP is never automatic from a transient failure and never weakens privacy or same-target proof.

## Gate

Pass only when the recovery record identifies the channel used, proves that it attached to the same user-owned tab, and confirms that no new browser surface was created.
