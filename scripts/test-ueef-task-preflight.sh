#!/usr/bin/env sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
out=$("$root/scripts/get-ueef-task-preflight.sh" 'Unix release task')
printf '%s' "$out" | grep -q 'READY_WITH_FALLBACK'
printf '%s' "$out" | grep -q 'UNSUPPORTED_ON_UNIX'

readonly_out=$("$root/scripts/get-ueef-task-preflight.sh" 'Explain dependency injection')
printf '%s' "$readonly_out" | grep -q '"tier": "T0"'
if printf '%s' "$readonly_out" | grep -q '"codeChange": true'; then
  echo 'Unix preflight invented a code change for a read-only explanation.' >&2
  exit 1
fi

backend_out=$("$root/scripts/get-ueef-task-preflight.sh" 'Implement a backend API endpoint')
printf '%s' "$backend_out" | grep -Eq '"tier": "T[1234]"'
printf '%s' "$backend_out" | grep -q '"codeChange": true'
