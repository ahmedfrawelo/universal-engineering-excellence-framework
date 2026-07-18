#!/usr/bin/env sh
set -eu
AGENT="codex"; FORCE=0; NO_BACKUP=0
while [ "$#" -gt 0 ]; do
  case "$1" in --agent) AGENT="$2"; shift 2;; --force) FORCE=1; shift;; --no-backup) NO_BACKUP=1; shift;; *) AGENT="$1"; shift;; esac
done
[ "$NO_BACKUP" = 0 ] || [ "$FORCE" = 1 ] || { echo "--no-backup requires --force" >&2; exit 1; }
first=$(printf '%.1s' "$AGENT"); case "$first" in [A-Za-z0-9]) ;; *) echo "Unsafe agent name: $AGENT" >&2; exit 1;; esac
case "$AGENT" in *[!A-Za-z0-9._-]*|.|..) echo "Unsafe agent name: $AGENT" >&2; exit 1;; esac
[ "${#AGENT}" -le 64 ] || { echo "Agent name is too long" >&2; exit 1; }
if [ -z "${CODEX_HOME:-}" ]; then
  echo "CODEX_HOME is required for exact Codex installation. Run inside Codex or export CODEX_HOME." >&2
  exit 1
fi
SOURCE_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
INSTALL_ROOT="$CODEX_HOME/ueef"
mkdir -p "$INSTALL_ROOT"
INSTALL_ROOT=$(CDPATH= cd -- "$INSTALL_ROOT" && pwd)
TARGET="$INSTALL_ROOT/$AGENT"
BACKUP_ROOT="$INSTALL_ROOT/backups"
[ -d "$SOURCE_ROOT/framework" ] || { echo "framework directory not found" >&2; exit 1; }
if [ "$TARGET" = "$SOURCE_ROOT" ]; then echo "UEEF is already running from $TARGET; install is a no-op."; exit 0; fi
case "$TARGET/" in "$SOURCE_ROOT/"*) echo "Refusing target inside source: $TARGET" >&2; exit 1;; esac
case "$SOURCE_ROOT/" in "$TARGET/"*) echo "Refusing source inside target: $SOURCE_ROOT" >&2; exit 1;; esac
if [ -e "$TARGET" ]; then
  [ "$FORCE" = 1 ] || { echo "Existing install found. Re-run with --force." >&2; exit 1; }
  if [ "$NO_BACKUP" = 0 ]; then
    mkdir -p "$BACKUP_ROOT"
    backup=$(mktemp -d "$BACKUP_ROOT/${AGENT}-$(date +%Y%m%d%H%M%S).XXXXXX")
    cp -R "$TARGET/." "$backup/"
  fi
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
