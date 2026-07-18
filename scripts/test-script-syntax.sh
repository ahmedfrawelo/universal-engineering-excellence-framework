#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
find "$ROOT/scripts" -name '*.sh' -type f -exec sh -n {} \;
find "$ROOT/scripts" -name '*.mjs' -type f -exec node --check {} \;
if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -File "$ROOT/scripts/test-script-syntax.ps1" -SkipShell >/dev/null
elif command -v powershell.exe >/dev/null 2>&1; then
  script="$ROOT/scripts/test-script-syntax.ps1"
  command -v cygpath >/dev/null 2>&1 && script=$(cygpath -w "$script")
  powershell.exe -NoProfile -File "$script" -SkipShell >/dev/null
fi
echo 'Cross-platform script syntax tests passed'
