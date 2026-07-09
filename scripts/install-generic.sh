#!/usr/bin/env sh
set -eu
AGENT="${1:-generic}"
INSTALL_ROOT="${UEEF_HOME:-$HOME/.ueef}"
SOURCE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
FRAMEWORK="$SOURCE_DIR/framework"
TARGET="$INSTALL_ROOT/$AGENT"
BACKUP="$INSTALL_ROOT/backups/$AGENT-$(date +%Y%m%d%H%M%S)"
if [ ! -d "$FRAMEWORK" ]; then
  echo "Cannot find framework directory at $FRAMEWORK" >&2
  exit 1
fi
if [ -e "$TARGET" ]; then
  printf "Existing UEEF installation found at %s. Back it up and replace it? (y/N) " "$TARGET"
  read ans
  case "$ans" in y|Y|yes|YES) mkdir -p "$(dirname "$BACKUP")"; cp -R "$TARGET" "$BACKUP" ;; *) echo "Install cancelled."; exit 1 ;; esac
fi
mkdir -p "$TARGET"
rm -rf "$TARGET/framework"
cp -R "$FRAMEWORK" "$TARGET/framework"
cat > "$TARGET/UEEF-LOADER.md" <<EOF
# UEEF Loader For $AGENT

Load UEEF before every engineering task. Read framework/MASTER_INDEX.md, inspect the project, detect stack and architecture, detect tools and skills, apply relevant modules, plan before editing, protect user work, run quality gates, and finish with evidence.
EOF
echo "UEEF installed for $AGENT at $TARGET"
echo "Loader: $TARGET/UEEF-LOADER.md"
