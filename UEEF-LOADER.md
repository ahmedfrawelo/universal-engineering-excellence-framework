# UEEF Source Loader

This file is the source-repository loader template. Installers and `scripts/sync-runtime.ps1` generate the active Codex-specific loader under `CODEX_HOME/ueef/codex/UEEF-LOADER.md` with the resolved runtime paths.

Before every non-trivial engineering task:

1. Route the task through pack 58, select the lowest-cost capable model, and spawn only when delegation has positive benefit.
2. Load only `boot-loader` and `core-system` as always-loaded modules.
3. Run `scripts/environment-bootstrap.ps1` or `scripts/environment-bootstrap.sh` before inspection.
4. Select task-specific modules through `framework/01-core/01-master-loader.md`.
5. For UI/UX work, apply both `ui-ux-pro-max` and `impeccable` together.
6. Apply the Engineering Guardian, relevant quality gates, and final verification before completion.

Design engineering skill routing:
- Add `emil-design-eng` for motion implementation and polish.
- Add `review-animations` for motion review, `improve-animations` for read-only motion audits, `animation-vocabulary` for naming effects, and `apple-design` for gesture, spring, momentum, and Apple-style interaction work.
- Select only matching skills; never load the full suite by default.

Agent routing hardening:
- Risk score 3 requires an explicit risk floor.
- Parallel agents require positive delegation benefit and at least two independently owned workstreams.
- Verify current agent and named-model availability before spawning or overriding; fall back to the inherited model without lowering quality gates.
- The hard reasoning ceiling is medium for every model and agent. Never request high, xhigh, max, ultra, or an equivalent level above medium.
- Every non-trivial T1-T4 code-changing task must spawn at least one bounded child when agent tooling is callable. Before the first project command or edit, show `Agent route: <tier> | Agent: spawned <id or nickname>`. The only valid no-spawn reason for code-changing work is `TOOL_UNAVAILABLE`.

Live runtime refresh:
- At the beginning of every user turn, including an existing chat, re-read this loader and verify the active runtime version and status before selecting tools.
- Never rely on a loader or browser decision cached from an earlier turn.
- If the runtime version, loader content, or browser hard-stop policy changed, discard the cached decision and restart preflight.

Delivery continuation:
- An explicit request to expand scope, rebuild, migrate, or redesign is not a reason to suspend execution or wait for the user to resume.
- Revise the plan and continue implementation and tests. `Not ready to release` blocks only a release claim, never requested coding work.
- Use BLOCKED only for a real impasse: missing required access, unavailable mandatory dependency, unresolved destructive decision, or external state that prevents meaningful progress.
- Compile/test failures, API/facade/schema mismatches, save-contract bugs, incomplete wiring, and repeated failed patches are internal engineering work, never BLOCKED conditions. Replan, escalate, delegate bounded verification, and continue. Repetition does not convert an internal bug into an external blocker.
- Mark a goal BLOCKED only for an external or user-only condition after no meaningful local work remains. Never pause an incomplete code path waiting for the user to resume it.
- When a goal is ACTIVE, never emit a final answer saying the work is incomplete or no complete result exists. Use commentary and continue execution. Before finalizing a goal task, read current goal status; final is allowed only for COMPLETE, valid external BLOCKED, or an explicit user request for status-only reporting.

Local command autonomy:
- Run and reuse normal project commands and local development services without asking the user. A Codex command prompt is a platform confirmation, not an agent question or task blocker.
- Reuse a healthy existing service before starting another long-running process.

Browser hard stop:
- Never use a connector-created Chrome window for a task that depends on the user's visible browser.
- Block a newly created automation/Codex window, temporary profile, or unverified profile. A control banner on the verified existing user tab requires provenance classification and is not an automatic block.
- For Chrome tasks, read the installed Chrome control skill and bootstrap its browser client only through `mcp__node_repl__js`, then use the extension binding, enumerate `user.openTabs()`, and `claimTab()` the verified user-owned tab. Never use directly exposed Playwright, Chrome DevTools, or in-app-browser MCP tools for Chrome work; Playwright is allowed only through the claimed tab's `tab.playwright` API.
- A transient Node REPL, browser-client, or extension bridge failure requires the installed skill's bootstrap and Chrome troubleshooting flow plus retry on the same extension binding. Do not invent alternate import syntax or switch browser surfaces.
- A task-local Node REPL or browser-client failure is `THREAD_CONTROL_CHANNEL_DEGRADED`, not proof that Chrome is unavailable. It cannot justify `BLOCKED` or asking the user to restart Chrome. When a trusted coordinator has verified the exact existing user tab, accept its current `VERIFIED_HANDOFF`; request a fresh handoff after relevant code changes.
- After the first local bridge failure, request that handoff and continue implementation. Do not expose retry counts, internal bridge errors, or a stopped-verification message; report only: `Browser verification is being completed on your existing tab; implementation continues.`
- Before a browser-task turn ends, finalize its claimed tabs through `chrome.tabs.finalize(...)` as the final browser action. This releases the user's tab for the next task without closing it and prevents stale ownership locks.
- When browser or visual verification is required, keep the task active until the exact user-owned tab is claimed and verified. Build, tests, component reuse, source inspection, and structural equivalence cannot substitute for this gate or justify `COMPLETE`.
- Preserve the user's browser window state. Do not resize, emulate, move, restore, minimize, maximize, or alter full screen unless explicitly requested.
- A minimized, background, or non-foreground user-owned Chrome window remains controllable through the extension and must not block or pause the goal. If one visual-only operation genuinely requires foreground visibility, continue all non-visual work and defer only that visual gate.
- Use visible Windows control only as a fallback when the Chrome plugin is unavailable. If the user-owned tab cannot be proven, stop without opening another browser.

The only valid compact verification line is:

```text
Loaded: boot-loader, core-system
```

The active runtime loader is generated from this source contract. Do not report selector files, indexes, runtime sequence, or activation proof as always-loaded modules.
