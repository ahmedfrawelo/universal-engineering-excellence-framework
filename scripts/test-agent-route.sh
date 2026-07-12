#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
selector="$ROOT/scripts/select-agent-route.sh"

assert_contains() {
  output="$1" expected="$2"
  printf '%s' "$output" | grep -Fq "$expected" || { echo "Expected $expected in $output" >&2; exit 1; }
}

route="$("$selector")"
assert_contains "$route" '"schemaVersion":1'
assert_contains "$route" '"tier":"T0"'
assert_contains "$route" '"spawnAgents":false'

route="$("$selector" --scope 2 --ambiguity 2 --coupling 1 --risk 1 --verification 1 --delegation-benefit)"
assert_contains "$route" '"tier":"T2"'
assert_contains "$route" '"topology":"lead-plus-sidecar"'

route="$("$selector" --risk-floor Payment --delegation-benefit --independent-workstreams 2)"
assert_contains "$route" '"tier":"T4"'
assert_contains "$route" '"topology":"lead-workers-independent-verifier"'

route="$("$selector" --risk-floor Authentication --models-unavailable)"
assert_contains "$route" '"preferredModel":null'

route="$("$selector" --scope 2 --ambiguity 2 --coupling 1 --risk 1 --verification 1 --delegation-benefit --agents-unavailable)"
assert_contains "$route" '"agentsAvailable":false'
assert_contains "$route" '"spawnAgents":false'

if "$selector" --risk 3 >/dev/null 2>&1; then echo 'Risk 3 without floor was accepted' >&2; exit 1; fi
echo 'Unix agent route tests passed'
