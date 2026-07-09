#!/usr/bin/env sh
set -eu
AGENT="generic"
if [ "$#" -gt 0 ]; then AGENT="$1"; fi
SOURCE_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
if [ -n "${UEEF_INSTALL_ROOT:-}" ]; then
  INSTALL_ROOT="$UEEF_INSTALL_ROOT"
elif [ -n "${CODEX_HOME:-}" ]; then
  INSTALL_ROOT="$CODEX_HOME/ueef"
else
  INSTALL_ROOT="$(dirname "$SOURCE_ROOT")/ueef-runtime"
fi
TARGET="$INSTALL_ROOT/$AGENT"
BACKUP_ROOT="$INSTALL_ROOT/backups"
[ -d "$SOURCE_ROOT/framework" ] || { echo "framework directory not found" >&2; exit 1; }
if [ -e "$TARGET" ]; then
  printf "Existing UEEF install found at %s. Back up and replace? (y/N) " "$TARGET"
  read ans
  case "$ans" in y|Y|yes|YES) mkdir -p "$BACKUP_ROOT"; cp -R "$TARGET" "$BACKUP_ROOT/$AGENT-$(date +%Y%m%d%H%M%S)"; rm -rf "$TARGET" ;; *) echo "Install cancelled."; exit 1 ;; esac
fi
mkdir -p "$TARGET"
if command -v tar >/dev/null 2>&1; then
  (cd "$SOURCE_ROOT" && tar --exclude .git -cf - .) | (cd "$TARGET" && tar -xf -)
else
  cp -R "$SOURCE_ROOT/." "$TARGET/"
  rm -rf "$TARGET/.git"
fi
cat > "$TARGET/UEEF-LOADER.md" <<'EOF'
# UEEF Loader

Activate UEEF before every non-trivial engineering task. Report only framework/01-core/00-boot-loader.md and framework/01-core/00-core-system.md under Loaded. Use framework/01-core/01-master-loader.md only to select relevant modules. Do not load the full framework unless the task is about UEEF audit, update, install, validation, or rebuild. Finish with compact UEEF Verification.
EOF
if [ "$AGENT" = "codex" ] && [ -n "${CODEX_HOME:-}" ] && command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -File "$TARGET/scripts/sync-runtime.ps1" -SourcePath "$TARGET" -CodexHome "$CODEX_HOME" -Agent "$AGENT" >/dev/null
fi
echo "UEEF installed for $AGENT at $TARGET"
echo "Verify loader: $TARGET/UEEF-LOADER.md"
