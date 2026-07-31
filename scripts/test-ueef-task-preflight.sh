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

quick_ui_out=$("$root/scripts/get-ueef-task-preflight.sh" 'Fix spacing in an existing CSS component')
printf '%s' "$quick_ui_out" | grep -q '"frontendMode": "Quick"'
printf '%s' "$quick_ui_out" | grep -q '"typeui-fundamentals"'
if printf '%s' "$quick_ui_out" | grep -Eq '"(impeccable|ui-ux-pro-max|frontend-design)"'; then
  echo 'Unix preflight stacked unrelated design skills for Quick frontend work.' >&2
  exit 1
fi

build_ui_out=$("$root/scripts/get-ueef-task-preflight.sh" 'Build a new React dashboard')
printf '%s' "$build_ui_out" | grep -q '"frontendMode": "Build"'
printf '%s' "$build_ui_out" | grep -q '"frontend-design"'

audit_ui_out=$("$root/scripts/get-ueef-task-preflight.sh" 'Audit and polish the frontend visual design')
printf '%s' "$audit_ui_out" | grep -q '"frontendMode": "Audit"'
printf '%s' "$audit_ui_out" | grep -q '"impeccable"'
