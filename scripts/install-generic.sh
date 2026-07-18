#!/usr/bin/env sh
set -eu
AGENT=generic; FORCE=0; NO_BACKUP=0
while [ "$#" -gt 0 ]; do case "$1" in --agent) AGENT="$2"; shift 2;; --force) FORCE=1; shift;; --no-backup) NO_BACKUP=1; shift;; *) AGENT="$1"; shift;; esac; done
SOURCE_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
if [ -n "${UEEF_INSTALL_ROOT:-}" ]; then INSTALL_ROOT=$UEEF_INSTALL_ROOT
elif [ -n "${CODEX_HOME:-}" ]; then INSTALL_ROOT=$CODEX_HOME/ueef
else INSTALL_ROOT=$(dirname "$SOURCE_ROOT")/ueef-runtime; fi
exec sh "$SOURCE_ROOT/scripts/install-runtime.sh" "$SOURCE_ROOT" "$INSTALL_ROOT" "$AGENT" "$FORCE" "$NO_BACKUP"
