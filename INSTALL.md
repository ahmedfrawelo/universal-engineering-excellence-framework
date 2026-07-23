# Installation

UEEF installs globally by copying the framework and writing an assistant loader. Use PowerShell on Windows and shell scripts on macOS/Linux. Installers detect likely global rule locations, ask before overwriting, back up existing files, print verification steps, and fail safely.

The current release is 2.14.0.

## Codex

```powershell
.\scripts\install-codex.ps1
```

```sh
./scripts/install-codex.sh
```

The Codex installer also installs the pinned Open Design `design-brief` and `frontend-design` skills when they are missing. They are optional runtime specialists; `ui-ux-pro-max` and `impeccable` remain the required UI/UX baseline.

## Cursor

```powershell
.\scripts\install-cursor.ps1
```

```sh
./scripts/install-cursor.sh
```

## Generic AI

```powershell
.\scripts\install-generic.ps1
```

```sh
./scripts/install-generic.sh
```

## Manual Installation

Copy the repository's `framework/` directory and `UEEF-LOADER.md` to the global assistant rules location. Configure the global assistant rules to read the copied `UEEF-LOADER.md` before every non-trivial task; do not point the global loader directly at `framework/01-core/01-master-loader.md`.

The copied loader must preserve the boot contract: it always loads `framework/01-core/00-boot-loader.md` and `framework/01-core/00-core-system.md`. It then uses `framework/01-core/01-master-loader.md` only to select task-specific modules.

## Update

Run `scripts/update.ps1` or `scripts/update.sh` from either the source repository or an installed runtime. A generated runtime uses `UEEF-ACTIVE.json` to update the recorded Git source and then regenerate itself; it never attempts `git pull` inside the copied non-Git runtime.

## Uninstall

Remove the copied UEEF folder from the printed install location after confirming backups exist.

## Troubleshooting

Run scripts/validate-framework.ps1 or scripts/validate-framework.sh and verify framework/00-foundation/README.md, framework/01-core/01-master-loader.md, and the global loader exist.

## Verify Activation

After installation, run:

```powershell
.\scripts\ueef-status.ps1
```

UEEF is active only when the result shows Installed: YES, Global loader: PASS, and Overall: ACTIVE. If the global AI rules path cannot be detected, follow docs/verify-ueef-is-active.md and set UEEF_GLOBAL_PATH to the Codex runtime path containing UEEF-LOADER.md.
## Exact Codex installation

For Codex, UEEF installs exactly into the active Codex runtime. `CODEX_HOME` is required. The installer must create:

- `CODEX_HOME/AGENTS.md`
- `CODEX_HOME/ueef/codex`
- `CODEX_HOME/ueef/codex/UEEF-LOADER.md`
- `CODEX_HOME/ueef/UEEF-ACTIVE.json`

If `CODEX_HOME` is missing, `scripts/install-codex.ps1` and `scripts/install-codex.sh` must fail instead of installing to a fallback path.

## Updating UEEF

This repository's current release is 2.14.0. From the repository root, run `git pull`, then `powershell -ExecutionPolicy Bypass -File .\scripts\validate-framework.ps1`. Re-run the Windows installer with `-Force` or the Unix installer with `--force` so the active runtime receives the current framework and loader; omit `-NoBackup`/`--no-backup` to keep a recovery copy. Codex installation remains self-contained under `CODEX_HOME/ueef/codex`; it does not install a fallback runtime under the user profile.
