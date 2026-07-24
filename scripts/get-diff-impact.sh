#!/usr/bin/env sh
set -eu
root="${1:-.}"
base="${2:-HEAD}"
files="$(git -C "$root" diff --name-only "$base")"
count="$(printf '%s\n' "$files" | sed '/^$/d' | wc -l | tr -d ' ')"
printf '{"schemaVersion":1,"repositoryPath":"%s","base":"%s","fileCount":%s,"confidence":"HEURISTIC","limitations":"Path-based analysis only; inspect imports, contracts, and tests before relying on it."}\n' "$root" "$base" "$count"
