#!/usr/bin/env sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sandbox=$(mktemp -d); trap 'rm -rf "$sandbox"' EXIT
out="$sandbox/evidence.json"; "$root/scripts/export-ueef-evidence.sh" "$root" "$out" true >/dev/null
node -e 'const r=require(process.argv[1]);if(r.schemaVersion!==1||!r.redaction||!r.diff)process.exit(1)' "$out"
