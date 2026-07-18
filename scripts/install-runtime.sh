#!/usr/bin/env sh
set -eu

SOURCE_ROOT=${1:?source root required}
INSTALL_ROOT=${2:?install root required}
AGENT=${3:?agent required}
FORCE=${4:-0}
NO_BACKUP=${5:-0}

first=$(printf '%.1s' "$AGENT"); case "$first" in [A-Za-z0-9]) ;; *) echo "Unsafe agent name: $AGENT" >&2; exit 1;; esac
case "$AGENT" in *[!A-Za-z0-9._-]*|.|..) echo "Unsafe agent name: $AGENT" >&2; exit 1;; esac
[ "${#AGENT}" -le 64 ] || { echo "Agent name is too long" >&2; exit 1; }
[ "$NO_BACKUP" = 0 ] || [ "$FORCE" = 1 ] || { echo "--no-backup requires --force" >&2; exit 1; }
SOURCE_ROOT=$(CDPATH= cd -- "$SOURCE_ROOT" && pwd -P)
mkdir -p "$INSTALL_ROOT"
INSTALL_ROOT=$(CDPATH= cd -- "$INSTALL_ROOT" && pwd -P)
TARGET="$INSTALL_ROOT/$AGENT"
case "$TARGET/" in "$SOURCE_ROOT/"*) echo "Refusing target inside source: $TARGET" >&2; exit 1;; esac
case "$SOURCE_ROOT/" in "$TARGET/"*) echo "Refusing source inside target: $SOURCE_ROOT" >&2; exit 1;; esac
[ ! -L "$TARGET" ] || { echo "Refusing symbolic-link target: $TARGET" >&2; exit 1; }

sh "$SOURCE_ROOT/scripts/validate-framework.sh" "$SOURCE_ROOT" >/dev/null
STAGE=$(mktemp -d "$INSTALL_ROOT/.sXXXXXX")
ROLLBACK="$INSTALL_ROOT/.r$$"
swapped=0
restore_on_failure() {
  status=$?
  if [ "$status" -ne 0 ]; then
    [ "$swapped" = 0 ] || rm -rf -- "$TARGET"
    [ ! -e "$ROLLBACK" ] || mv -- "$ROLLBACK" "$TARGET"
  fi
  [ ! -e "$STAGE" ] || rm -rf -- "$STAGE"
  exit "$status"
}
trap restore_on_failure EXIT HUP INT TERM
node "$SOURCE_ROOT/scripts/copy-release-files.mjs" "$SOURCE_ROOT" "$STAGE" --include-loader >/dev/null
sh "$STAGE/scripts/validate-framework.sh" "$STAGE" >/dev/null
if [ -e "$TARGET" ]; then
  [ "$FORCE" = 1 ] || { echo "Existing install found. Re-run with --force." >&2; exit 1; }
  if [ "$NO_BACKUP" = 0 ]; then
    mkdir -p "$INSTALL_ROOT/backups"
    backup=$(mktemp -d "$INSTALL_ROOT/backups/${AGENT}-$(date +%Y%m%d%H%M%S).XXXXXX")
    cp -R "$TARGET/." "$backup/"
  fi
  mv -- "$TARGET" "$ROLLBACK"
fi
mv -- "$STAGE" "$TARGET"
swapped=1
"$TARGET/scripts/write-active-state.sh" "$TARGET" "$INSTALL_ROOT" "$AGENT" "$SOURCE_ROOT" "$(dirname "$INSTALL_ROOT")" 0 >/dev/null
[ ! -e "$ROLLBACK" ] || rm -rf -- "$ROLLBACK"
swapped=0
trap - EXIT HUP INT TERM
echo "UEEF installed for $AGENT at $TARGET"
echo "Verify loader: $TARGET/UEEF-LOADER.md"
