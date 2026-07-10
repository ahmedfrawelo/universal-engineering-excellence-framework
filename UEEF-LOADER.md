# UEEF Source Loader

This file is the source-repository loader template. Installers and `scripts/sync-runtime.ps1` generate the active Codex-specific loader under `CODEX_HOME/ueef/codex/UEEF-LOADER.md` with the resolved runtime paths.

Before every non-trivial engineering task:

1. Load only `boot-loader` and `core-system` as always-loaded modules.
2. Run `scripts/environment-bootstrap.ps1` or `scripts/environment-bootstrap.sh` before inspection.
3. Select task-specific modules through `framework/01-core/01-master-loader.md`.
4. For UI/UX work, apply both `ui-ux-pro-max` and `impeccable` together.
5. Apply the Engineering Guardian, relevant quality gates, and final verification before completion.

Live runtime refresh:
- At the beginning of every user turn, including an existing chat, re-read this loader and verify the active runtime version and status before selecting tools.
- Never rely on a loader or browser decision cached from an earlier turn.
- If the runtime version, loader content, or browser hard-stop policy changed, discard the cached decision and restart preflight.

Browser hard stop:
- Never use a connector-created Chrome window for a task that depends on the user's visible browser.
- A `Chrome is being controlled by automated test software` banner, Codex-titled browser window, or unverified profile is a BLOCKED browser session.
- Prefer visible Windows window control for the user's active browser. If the active window cannot be proven, stop without opening or controlling another browser.

The only valid compact verification line is:

```text
Loaded: boot-loader, core-system
```

The active runtime loader is generated from this source contract. Do not report selector files, indexes, runtime sequence, or activation proof as always-loaded modules.
