#!/usr/bin/env sh
set -eu
AGENT="${1:-codex}"
if [ -n "${UEEF_INSTALL_ROOT:-}" ]; then
  INSTALL_ROOT="$UEEF_INSTALL_ROOT"
elif [ -n "${CODEX_HOME:-}" ]; then
  INSTALL_ROOT="$CODEX_HOME/ueef"
else
  INSTALL_ROOT="$(dirname "$SOURCE_ROOT")/ueef-runtime"
fi
SOURCE_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TARGET="$INSTALL_ROOT/$AGENT"
BACKUP_ROOT="$INSTALL_ROOT/backups"
[ -d "$SOURCE_ROOT/framework" ] || { echo "framework directory not found" >&2; exit 1; }
if [ -e "$TARGET" ]; then
  printf "Existing UEEF install found at %s. Back up and replace? (y/N) " "$TARGET"
  read ans
  case "$ans" in y|Y|yes|YES) mkdir -p "$BACKUP_ROOT"; cp -R "$TARGET" "$BACKUP_ROOT/$AGENT-$(date +%Y%m%d%H%M%S)" ;; *) echo "Install cancelled."; exit 1 ;; esac
fi
mkdir -p "$TARGET"
rm -rf "$TARGET/framework"
cp -R "$SOURCE_ROOT/framework" "$TARGET/framework"
cat > "$TARGET/UEEF-LOADER.md" <<EOF
# UEEF Loader

Load UEEF before every non-trivial engineering task. Always load only framework/01-core/00-boot-loader.md and framework/01-core/00-core-system.md. Use framework/01-core/01-master-loader.md only to select relevant modules. Do not load the full framework unless the task is about UEEF audit, update, install, validation, or rebuild. Finish with compact UEEF Verification.
EOF
echo "UEEF installed for $AGENT at $TARGET"
echo "Verify loader: $TARGET/UEEF-LOADER.md"
