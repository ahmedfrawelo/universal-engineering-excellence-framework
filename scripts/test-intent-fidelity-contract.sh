#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

require_term() {
  file="$1" term="$2"
  grep -Fq "$term" "$ROOT/$file" || { echo "Intent-fidelity term missing from $file: $term" >&2; exit 1; }
}

require_term UEEF-LOADER.md 'Scope wins'
require_term framework/01-core/00-core-system.md 'Scope wins'
require_term framework/01-core/13-autonomy-and-confirmation-policy.md 'Scope Wins'
require_term framework/01-core/14-delivery-continuation-policy.md 'Stop When Done'
require_term framework/58-agent-model-orchestration/02-model-capability-routing.md 'economical default, not a hard ceiling'
require_term framework/58-agent-model-orchestration/00-agent-model-orchestration-system.md 'A single-agent T1 route with `NO_INDEPENDENT_WORK` needs no child-agent evidence.'
require_term framework/01-core/01-master-loader.md '`medium` is the economical reasoning default.'
require_term examples/intent-fidelity-fixtures.md 'Agent route: T1 | Agent: not spawned - NO_INDEPENDENT_WORK'

for file in UEEF-LOADER.md framework/01-core/01-master-loader.md framework/58-agent-model-orchestration/00-agent-model-orchestration-system.md framework/27-quality-gates/31-agent-model-routing-gate.md scripts/select-agent-route.ps1 scripts/select-agent-route.sh; do
  if grep -Eiq 'For every non-trivial T1-T4 code change, spawn at least one bounded child|only valid no-spawn reason|No route may emit or request a higher level|reasoning ceiling is `medium`|Cap every requested.*medium|never request a reasoning level above medium' "$ROOT/$file"; then
    echo "An absolute intent-routing contract remains in $file." >&2
    exit 1
  fi
done

t1="$("$ROOT/scripts/select-agent-route.sh" --code-change)"
printf '%s' "$t1" | grep -Fq '"tier":"T1"'
printf '%s' "$t1" | grep -Fq '"spawnAgents":false'
printf '%s' "$t1" | grep -Fq '"noSpawnReason":"NO_INDEPENDENT_WORK"'
printf '%s\n' 'Unix intent fidelity contract tests passed'
