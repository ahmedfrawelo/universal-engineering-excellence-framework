#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
selector="$ROOT/scripts/select-agent-route.sh"

assert_contains() {
  output="$1" expected="$2"
  printf '%s' "$output" | grep -Fq "$expected" || { echo "Expected $expected in $output" >&2; exit 1; }
}

route="$("$selector")"
assert_contains "$route" '"schemaVersion":4'
assert_contains "$route" '"tier":"T0"'
assert_contains "$route" '"reasoning":"medium"'
assert_contains "$route" '"reasoningCeiling":"proportional"'
assert_contains "$route" '"spawnAgents":false'

route="$("$selector" --code-change)"
assert_contains "$route" '"tier":"T1"'
assert_contains "$route" '"codeChange":true'
assert_contains "$route" '"spawnAgents":false'
assert_contains "$route" '"noSpawnReason":"NO_INDEPENDENT_WORK"'
assert_contains "$route" '"routeEvidenceRequired":true'

route="$("$selector" --code-change --agents-unavailable)"
assert_contains "$route" '"spawnAgents":false'
assert_contains "$route" '"noSpawnReason":"TOOL_UNAVAILABLE"'

route="$("$selector" --scope 2 --ambiguity 2 --coupling 1 --risk 1 --verification 1 --delegation-benefit)"
assert_contains "$route" '"tier":"T2"'
assert_contains "$route" '"topology":"lead-plus-sidecar"'

route="$("$selector" --risk-floor Payment --delegation-benefit --independent-workstreams 2)"
assert_contains "$route" '"tier":"T4"'
assert_contains "$route" '"reasoning":"high"'
assert_contains "$route" '"topology":"lead-workers-independent-verifier"'

route="$("$selector" --risk-floor Authentication --models-unavailable)"
assert_contains "$route" '"preferredModel":null'

route="$("$selector" --scope 2 --ambiguity 2 --coupling 1 --risk 1 --verification 1 --delegation-benefit --agents-unavailable)"
assert_contains "$route" '"agentsAvailable":false'
assert_contains "$route" '"spawnAgents":false'

if "$selector" --risk 3 >/dev/null 2>&1; then echo 'Risk 3 without floor was accepted' >&2; exit 1; fi
for route in \
  "$("$selector")" \
  "$("$selector" --scope 1 --ambiguity 1 --coupling 1 --risk 1 --verification 1)" \
  "$("$selector" --risk-floor Authentication)" \
  "$("$selector" --risk-floor Privacy)"
do
  printf '%s' "$route" | grep -Eq '"reasoning":"(low|medium|high)"' || { echo "Unsupported proportional reasoning level in $route" >&2; exit 1; }
done
capability_routing="$ROOT/framework/58-agent-model-orchestration/02-model-capability-routing.md"
if ! grep -Fq 'economical default, not a hard ceiling' "$capability_routing"; then
  echo 'Model capability routing does not document proportional reasoning.' >&2
  exit 1
fi
echo 'Unix agent route tests passed'
