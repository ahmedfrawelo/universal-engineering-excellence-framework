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

Local command autonomy:
- Run and reuse normal project commands and local development services without asking the user. A Codex command prompt is a platform confirmation, not an agent question or task blocker.
- Reuse a healthy existing service before starting another long-running process.

Browser hard stop:
- Never use a connector-created Chrome window for a task that depends on the user's visible browser.
- A `Chrome is being controlled by automated test software` banner, Codex-titled browser window, or unverified profile is a BLOCKED browser session.
- Prefer visible Windows control for ordinary browser interaction. Use Chrome debugging only for debugging-specific capabilities such as DOM, console, network, or performance inspection.
- Preserve the user's browser window state. Do not resize, emulate, move, restore, minimize, maximize, or alter full screen unless explicitly requested.
- Prefer visible Windows window control for the user's active browser. If the active window cannot be proven, stop without opening or controlling another browser.

The only valid compact verification line is:

```text
Loaded: boot-loader, core-system
```

The active runtime loader is generated from this source contract. Do not report selector files, indexes, runtime sequence, or activation proof as always-loaded modules.
