#!/usr/bin/env sh
set -eu
AGENT="codex"
if [ "$#" -gt 0 ]; then AGENT="$1"; fi
if [ -z "${CODEX_HOME:-}" ]; then
  echo "CODEX_HOME is required for exact Codex installation. Run inside Codex or export CODEX_HOME." >&2
  exit 1
fi
SOURCE_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
INSTALL_ROOT="$CODEX_HOME/ueef"
TARGET="$INSTALL_ROOT/$AGENT"
BACKUP_ROOT="$INSTALL_ROOT/backups"
[ -d "$SOURCE_ROOT/framework" ] || { echo "framework directory not found" >&2; exit 1; }
if [ -e "$TARGET" ]; then
  printf "Existing UEEF install found at %s. Back up and replace? (y/N) " "$TARGET"
  read ans
  case "$ans" in y|Y|yes|YES) mkdir -p "$BACKUP_ROOT"; cp -R "$TARGET" "$BACKUP_ROOT/$AGENT-$(date +%Y%m%d%H%M%S)"; rm -rf "$TARGET" ;; *) echo "Install cancelled."; exit 1 ;; esac
fi
if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -File "$SOURCE_ROOT/scripts/sync-runtime.ps1" -SourcePath "$SOURCE_ROOT" -CodexHome "$CODEX_HOME" -Agent "$AGENT"
elif command -v powershell.exe >/dev/null 2>&1; then
  powershell.exe -NoProfile -File "$SOURCE_ROOT/scripts/sync-runtime.ps1" -SourcePath "$SOURCE_ROOT" -CodexHome "$CODEX_HOME" -Agent "$AGENT"
else
  echo "PowerShell is required for exact Codex installation because sync-runtime.ps1 writes AGENTS.md and UEEF-ACTIVE.json." >&2
  exit 1
fi
echo "UEEF Codex runtime installed exactly from repository source."
echo "Runtime: $TARGET"
echo "Codex AGENTS: $CODEX_HOME/AGENTS.md"
echo "Active state: $INSTALL_ROOT/UEEF-ACTIVE.json"
