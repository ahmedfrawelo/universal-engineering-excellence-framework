#!/usr/bin/env sh
set -eu
AGENT="generic"; FORCE=0; NO_BACKUP=0
while [ "$#" -gt 0 ]; do case "$1" in --agent) AGENT="$2"; shift 2;; --force) FORCE=1; shift;; --no-backup) NO_BACKUP=1; shift;; *) AGENT="$1"; shift;; esac; done
[ "$NO_BACKUP" = 0 ] || [ "$FORCE" = 1 ] || { echo "--no-backup requires --force" >&2; exit 1; }
first=$(printf '%.1s' "$AGENT"); case "$first" in [A-Za-z0-9]) ;; *) echo "Unsafe agent name: $AGENT" >&2; exit 1;; esac
case "$AGENT" in *[!A-Za-z0-9._-]*|.|..) echo "Unsafe agent name: $AGENT" >&2; exit 1;; esac
[ "${#AGENT}" -le 64 ] || { echo "Agent name is too long" >&2; exit 1; }
SOURCE_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
if [ -n "${UEEF_INSTALL_ROOT:-}" ]; then
  INSTALL_ROOT="$UEEF_INSTALL_ROOT"
elif [ -n "${CODEX_HOME:-}" ]; then
  INSTALL_ROOT="$CODEX_HOME/ueef"
else
  INSTALL_ROOT="$(dirname "$SOURCE_ROOT")/ueef-runtime"
fi
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
  if [ "$NO_BACKUP" = 0 ]; then mkdir -p "$BACKUP_ROOT"; cp -R "$TARGET" "$BACKUP_ROOT/$AGENT-$(date +%Y%m%d%H%M%S)"; fi
  rm -rf "$TARGET"
fi
mkdir -p "$TARGET"
if command -v tar >/dev/null 2>&1; then
  (cd "$SOURCE_ROOT" && tar --exclude .git -cf - .) | (cd "$TARGET" && tar -xf -)
else
  cp -R "$SOURCE_ROOT/." "$TARGET/"
  rm -rf "$TARGET/.git"
fi
"$TARGET/scripts/write-active-state.sh" "$TARGET" "$INSTALL_ROOT" "$AGENT" "$SOURCE_ROOT" "$(dirname "$INSTALL_ROOT")" 0 >/dev/null
echo "UEEF installed for $AGENT at $TARGET"
echo "Verify loader: $TARGET/UEEF-LOADER.md"
