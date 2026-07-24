#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
out="$(sh "$root/scripts/get-diff-impact.sh" "$root")"
printf '%s' "$out" | grep -q '"schemaVersion":1'
if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf '%s' "$out" | grep -q '"confidence":"HEURISTIC"'
else
  printf '%s' "$out" | grep -q '"confidence":"UNAVAILABLE"'
fi
echo 'Unix diff impact tests passed'
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
without_git="$(sh "$root/scripts/get-diff-impact.sh" "$sandbox")"
printf '%s' "$without_git" | grep -q '"confidence":"UNAVAILABLE"'
