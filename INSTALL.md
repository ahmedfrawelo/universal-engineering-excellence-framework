# Installation

UEEF installs globally by copying the framework and writing an assistant loader. Use PowerShell on Windows and shell scripts on macOS/Linux. Installers detect likely global rule locations, ask before overwriting, back up existing files, print verification steps, and fail safely.

## Codex

``powershell
.\scripts\install-codex.ps1
``

``sh
./scripts/install-codex.sh
``

## Cursor

``powershell
.\scripts\install-cursor.ps1
``

``sh
./scripts/install-cursor.sh
``

## Generic AI

``powershell
.\scripts\install-generic.ps1
``

``sh
./scripts/install-generic.sh
``

## Manual Installation

Copy framework/ to a global assistant rules folder and create a loader that points to framework/01-core/01-master-loader.md.

## Update

Run scripts/update.ps1 or scripts/update.sh from the repository root.

## Uninstall

Remove the copied UEEF folder from the printed install location after confirming backups exist.

## Troubleshooting

Run scripts/validate-framework.ps1 or scripts/validate-framework.sh and verify framework/00-foundation/README.md, framework/01-core/01-master-loader.md, and the global loader exist.

## Verify Activation

After installation, run:

`powershell
.\scripts\ueef-status.ps1
`

UEEF is active only when the result shows Installed: YES, Global loader: PASS, and Overall: ACTIVE. If the global AI rules path cannot be detected, follow docs/verify-ueef-is-active.md and set UEEF_GLOBAL_PATH to the Codex runtime path containing UEEF-LOADER.md.
## Exact Codex installation

For Codex, UEEF installs exactly into the active Codex runtime. `CODEX_HOME` is required. The installer must create:

- `CODEX_HOME/AGENTS.md`
- `CODEX_HOME/ueef/codex`
- `CODEX_HOME/ueef/codex/UEEF-LOADER.md`
- `CODEX_HOME/ueef/UEEF-ACTIVE.json`

If `CODEX_HOME` is missing, `scripts/install-codex.ps1` and `scripts/install-codex.sh` must fail instead of installing to a fallback path.
