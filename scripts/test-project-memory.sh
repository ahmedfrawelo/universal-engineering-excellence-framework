#!/usr/bin/env sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sandbox=$(mktemp -d); trap 'rm -rf "$sandbox"' EXIT
"$root/scripts/write-project-memory.sh" "$sandbox" decision cache 'Use explicit invalidation.' >/dev/null
"$root/scripts/get-project-memory.sh" "$sandbox" cache | grep -q 'explicit invalidation'
if "$root/scripts/write-project-memory.sh" "$sandbox" lesson bad 'api_key=secret' >/dev/null 2>&1; then exit 1; fi
