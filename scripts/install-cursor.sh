#!/usr/bin/env sh
set -eu
AGENT="${1:-cursor}"
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

Load UEEF before every engineering task. Start with framework/01-core/01-master-loader.md and framework/MASTER_INDEX.md. Inspect the project, detect stack and architecture, detect tools and skills, plan before editing, avoid duplication, prioritize security and performance, run quality gates, and finish with evidence.
EOF
echo "UEEF installed for $AGENT at $TARGET"
echo "Verify loader: $TARGET/UEEF-LOADER.md"
