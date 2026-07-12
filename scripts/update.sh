#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "${1:-$(dirname -- "$0")/..}" && pwd)
SOURCE_ROOT="$ROOT"
if ! git -C "$SOURCE_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  STATE_PATH="$(dirname "$ROOT")/UEEF-ACTIVE.json"
  [ -f "$STATE_PATH" ] || { echo "Runtime is not a Git checkout and has no UEEF-ACTIVE.json" >&2; exit 1; }
  SOURCE_ROOT=$(sed -n 's/.*"sourceRepositoryPath"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$STATE_PATH" | sed -n '1p')
  SOURCE_ROOT=$(printf '%s' "$SOURCE_ROOT" | sed 's/\\\\/\\/g')
  if command -v cygpath >/dev/null 2>&1; then SOURCE_ROOT=$(cygpath -u "$SOURCE_ROOT"); fi
  [ -d "$SOURCE_ROOT/.git" ] || { echo "Recorded source repository is unavailable: $SOURCE_ROOT" >&2; exit 1; }
fi
if [ "$SOURCE_ROOT" != "$ROOT" ]; then
  if command -v pwsh >/dev/null 2>&1; then
    pwsh -NoProfile -File "$ROOT/scripts/update.ps1" -Root "$ROOT"
  elif command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -File "$ROOT/scripts/update.ps1" -Root "$ROOT"
  else
    echo "PowerShell is required to update and regenerate this runtime safely." >&2
    exit 1
  fi
else
  git -C "$SOURCE_ROOT" pull --ff-only
  echo "Repository updated. Re-run installer for each agent."
fi
