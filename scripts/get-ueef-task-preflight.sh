#!/usr/bin/env sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
task=${1:-}
[ -n "$task" ] || { echo 'usage: get-ueef-task-preflight.sh "task summary"' >&2; exit 2; }
route=$("$root/scripts/select-agent-route.sh" --scope 2 --ambiguity 1 --coupling 1 --risk 1 --verification 2 --code-change)
node -e 'const route=JSON.parse(process.argv[1]); console.log(JSON.stringify({schemaVersion:1,status:"READY_WITH_FALLBACK",task:process.argv[2],route,profile:{profile:"SELECTIVE",limitations:"Unix preflight does not run capability health or callable probes."},health:{status:"UNSUPPORTED_ON_UNIX",detail:"No Unix capability-health implementation is available."}},null,2))' "$route" "$task"
