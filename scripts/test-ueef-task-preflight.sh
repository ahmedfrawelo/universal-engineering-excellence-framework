#!/usr/bin/env sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
out=$("$root/scripts/get-ueef-task-preflight.sh" 'Unix release task')
printf '%s' "$out" | grep -q 'READY_WITH_FALLBACK'
printf '%s' "$out" | grep -q 'UNSUPPORTED_ON_UNIX'
