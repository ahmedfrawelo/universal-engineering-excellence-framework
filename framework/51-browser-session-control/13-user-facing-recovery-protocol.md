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

## Local File URL Recovery

A Chrome security-policy rejection of a local `file://` URL is a navigation
restriction, not a broken Chrome control channel and not a reason to run runtime
sync. Preserve the same Chrome binding and dedicated task tab. Inspect the
project's documented local-server owner and expected port, reuse a healthy
loopback service for that same project, or start one bounded read-only static
server on `127.0.0.1` only after proving the chosen port is free. Navigate the
same artifact through `http://127.0.0.1:<port>/...`, then verify its DOM and
visible behavior normally.

Notify the user once in plain language:
`Chrome recovery: stage=local navigation; reason=file URL blocked by browser security; next=serve the same local artifact over 127.0.0.1 and continue in the same Chrome tab. Implementation continues.`

Do not open another browser/profile/context, claim the user's working tab,
invent a `file:///` variant, use runtime sync as a browser repair, or escalate
to CDP for this condition.

## Explicit Synthetic Playwright Contingency

After every authorized same-Chrome path has failed, an explicit user request
may authorize a standalone Playwright check only when the active host and
installed skill also permit it. This is limited to a public or loopback local
surface without the user's profile, login, cookies, storage, or existing tab.
Report it before execution as `SYNTHETIC_ONLY`, state that it does not access
the user's Chrome, and never use it as evidence that the real Chrome session,
extension, authentication, or visible tab works.

If the result depends on the real Chrome profile or existing tab, synthetic
Playwright is not a substitute. The authorized same-target loopback CDP path
remains the final eligible recovery, and stricter host or skill rules win.

## Exceptions

Only independently proven `CHROME_EXTERNALLY_UNAVAILABLE` permits a user-action request. The message must name the externally verified missing condition and required action; it must not rely on a task-local Node REPL failure.

The startup-order hint is the only allowed user-facing exception before independent Chrome-unavailable proof. It must be phrased as: open Chrome first, then restart Codex, then retry the browser task.

If every configured prior stage has failed, state that fact and request explicit authorization for `AUTHORIZED_LOOPBACK_LAST_RESORT`. An instruction that unambiguously says to use the emergency or authorized alternative applies only to this loopback path; it never permits the in-app browser or another browser surface.
