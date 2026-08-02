# User-Facing Browser Recovery Protocol

## Rule

`THREAD_CONTROL_CHANNEL_DEGRADED` is an internal transport condition. It must never be surfaced as only a generic connection/channel failure, a failed-attempt count, a stopped-verification notice, a Chrome-unavailable claim, or a `BLOCKED` status.

## Required Action

On the first local bridge failure, the task must stop repeating local bootstrap attempts in the same turn, preserve the user-owned Chrome surface, and automatically seek a `VERIFIED_HANDOFF` from a trusted coordinator. It continues all non-browser work while the handoff is obtained. It does not ask the user to acknowledge the transfer, restart Chrome, or open another browser.

If the failure happens before any tab-discovery evidence and Chrome may have been closed when Codex started, give the startup-order hint instead of a retry loop: ask the user to open Chrome first and then restart Codex. This is a host/browser binding prerequisite, not a Chrome-unavailable claim.

## Required User-Facing Diagnosis

Report one concise structured diagnosis containing all three fields:

- `stage`: the failed stage, such as Chrome selection, tab discovery, dedicated-tab creation, tab claim, ownership repair, handoff, visible Windows control, or emergency readiness.
- `reason`: the observed human-readable cause category and evidence, without raw stack traces or secrets.
- `next`: the next allowed recovery action.

Use: `Chrome recovery: stage=<stage>; reason=<reason>; next=<next>. Implementation continues.`

Do not expose attempt counts, internal MCP names, raw stack traces, cookies, storage, or secrets. Do not repeat the same diagnosis without new evidence. When the handoff arrives, report the verified outcome only.

## Exceptions

Only independently proven `CHROME_EXTERNALLY_UNAVAILABLE` permits a user-action request. The message must name the externally verified missing condition and required action; it must not rely on a task-local Node REPL failure.

The startup-order hint is the only allowed user-facing exception before independent Chrome-unavailable proof. It must be phrased as: open Chrome first, then restart Codex, then retry the browser task.

If every configured prior stage has failed, state that fact and request explicit authorization for `AUTHORIZED_LOOPBACK_LAST_RESORT`. An instruction that unambiguously says to use the emergency or authorized alternative applies only to this loopback path; it never permits the in-app browser or another browser surface.
