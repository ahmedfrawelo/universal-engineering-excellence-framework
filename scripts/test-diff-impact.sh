#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
out="$(sh "$root/scripts/get-diff-impact.sh" "$root")"
printf '%s' "$out" | grep -q '"schemaVersion":1'
printf '%s' "$out" | grep -q '"confidence":"HEURISTIC"'
echo 'Unix diff impact tests passed'
