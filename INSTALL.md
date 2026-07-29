# Installation

UEEF installs globally by copying the framework and writing an assistant loader. Use PowerShell on Windows and shell scripts on macOS/Linux. Installers detect likely global rule locations, ask before overwriting, back up existing files, print verification steps, and fail safely.

The current release is 2.19.0.

## Codex

```powershell
.\scripts\install-codex.ps1
```

```sh
./scripts/install-codex.sh
```

The authoritative optional-skill set is `config/preferred-skills.json`. Install every missing preferred skill from its pinned commit with:

```powershell
.\scripts\install-preferred-skills.ps1 -CodexHome "D:\shared folder\codex-home"
```

On Unix, set `CODEX_HOME` and run `scripts/install-preferred-skills.sh`. Both installers are missing-only: they preserve existing skill directories and refuse to overwrite an incomplete directory. Skills remain trigger-selected; installation does not load the full design suite into every task.

The old `codex-primary-runtime` folder is a runtime/plugin component rather than a user skill. The unprovenanced `codex-home-recovery` snapshot is retired in favor of transactional runtime rollback and Codex-home backups; both classifications are recorded in the preferred-skills manifest.

On Windows, Codex installation also registers a per-user background task that checks `origin/main` every 15 minutes and synchronizes the runtime when a newer release is available. Use `-SkipAutoUpdate` only when this behavior is not wanted.

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

After every release that changes browser policy, run `scripts/sync-runtime.ps1` from the source repository or reinstall the target adapter so its generated loader and `AGENTS.md` receive the policy. Then run `scripts/ueef-status.ps1` and require `Runtime drift: PASS`. If an assistant still opens or proposes another browser, profile, context, IDE browser, or in-app browser, synchronize immediately; updating the source checkout alone is not sufficient.

## Uninstall

Remove the copied UEEF folder from the printed install location after confirming backups exist.

## Troubleshooting

Run scripts/validate-framework.ps1 or scripts/validate-framework.sh and verify framework/00-foundation/README.md, framework/01-core/01-master-loader.md, and the global loader exist.

## Verify Activation

After installation, run:

```powershell
.\scripts\ueef-status.ps1
```

UEEF is active only when the result shows Installed: YES, Global loader: PASS, and Overall: ACTIVE. `SOURCE_VALIDATED` is a source-checkout result, not an installed-runtime claim. If the global AI rules path cannot be detected, follow docs/verify-ueef-is-active.md and set UEEF_GLOBAL_PATH to the Codex runtime path containing UEEF-LOADER.md.
## Exact Codex installation

For Codex, UEEF installs exactly into the active Codex runtime. `CODEX_HOME` is required. The installer must create:

- `CODEX_HOME/AGENTS.md`
- `CODEX_HOME/ueef/codex`
- `CODEX_HOME/ueef/codex/UEEF-LOADER.md`
- `CODEX_HOME/ueef/UEEF-ACTIVE.json`

If `CODEX_HOME` is missing, `scripts/install-codex.ps1` and `scripts/install-codex.sh` must fail instead of installing to a fallback path.

## Updating UEEF

This repository's current release is 2.19.0. From the repository root, run `git pull`, then `powershell -ExecutionPolicy Bypass -File .\scripts\validate-framework.ps1`. Re-run the Windows installer with `-Force` or the Unix installer with `--force` so the active runtime receives the current framework and loader; omit `-NoBackup`/`--no-backup` to keep a recovery copy. Codex installation remains self-contained under `CODEX_HOME/ueef/codex`; it does not install a fallback runtime under the user profile.
