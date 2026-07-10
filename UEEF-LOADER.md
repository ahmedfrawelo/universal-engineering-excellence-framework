# UEEF Source Loader

This file is the source-repository loader template. Installers and `scripts/sync-runtime.ps1` generate the active Codex-specific loader under `CODEX_HOME/ueef/codex/UEEF-LOADER.md` with the resolved runtime paths.

Before every non-trivial engineering task:

1. Load only `boot-loader` and `core-system` as always-loaded modules.
2. Run `scripts/environment-bootstrap.ps1` or `scripts/environment-bootstrap.sh` before inspection.
3. Select task-specific modules through `framework/01-core/01-master-loader.md`.
4. For UI/UX work, apply both `ui-ux-pro-max` and `impeccable` together.
5. Apply the Engineering Guardian, relevant quality gates, and final verification before completion.

The only valid compact verification line is:

```text
Loaded: boot-loader, core-system
```

The active runtime loader is generated from this source contract. Do not report selector files, indexes, runtime sequence, or activation proof as always-loaded modules.
