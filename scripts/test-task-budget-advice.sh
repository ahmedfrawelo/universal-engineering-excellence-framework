#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
out="$(sh "$root/scripts/get-task-budget-advice.sh" T4)"
printf '%s' "$out" | grep -q '"estimatedMinutes":90'
echo 'Unix task budget advice tests passed'
