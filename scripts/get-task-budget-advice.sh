#!/usr/bin/env sh
set -eu
tier="${1:-T1}"
case "$tier" in T0) minutes=1;;T1) minutes=5;;T2) minutes=18;;T3) minutes=45;;T4) minutes=90;;*) echo 'invalid tier' >&2; exit 2;;esac
printf '{"schemaVersion":1,"tier":"%s","estimatedMinutes":%s,"confidence":"HEURISTIC","limitations":"Planning estimate only; not token telemetry or a cost quote."}\n' "$tier" "$minutes"
