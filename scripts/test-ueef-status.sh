#!/usr/bin/env sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
out=$("$root/scripts/ueef-status.sh" "$root")
printf '%s\n' "$out" | grep -q '^Mode: source-checkout$'
printf '%s\n' "$out" | grep -q '^Installed: NO$'
printf '%s\n' "$out" | grep -q '^Codex AGENTS: NOT_APPLICABLE$'
printf '%s\n' "$out" | grep -q '^Active state: NOT_APPLICABLE$'
printf '%s\n' "$out" | grep -q '^Runtime drift: NOT_APPLICABLE$'
printf '%s\n' "$out" | grep -q '^Overall: SOURCE_VALIDATED$'
printf '%s\n' 'Unix source status tests passed'
