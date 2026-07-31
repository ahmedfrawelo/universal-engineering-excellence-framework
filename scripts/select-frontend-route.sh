#!/usr/bin/env sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
task=${1:-}
mode=${2:-Auto}
[ -n "$task" ] || { echo 'usage: select-frontend-route.sh "task summary" [Auto|Quick|Build|Audit]' >&2; exit 2; }
exec node "$root/scripts/select-frontend-route.mjs" --task "$task" --mode "$mode"
