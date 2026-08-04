#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
selector="$ROOT/scripts/select-agent-route.sh"
catalog="$ROOT/scripts/fixtures/model-catalog.json"

assert_contains() {
  output="$1" expected="$2"
  printf '%s' "$output" | grep -Fq "$expected" || { echo "Expected $expected in $output" >&2; exit 1; }
}

route="$("$selector" --model-catalog "$catalog" --test-model-catalog)"
assert_contains "$route" '"schemaVersion":4'
assert_contains "$route" '"tier":"T0"'
assert_contains "$route" '"reasoning":"low"'
assert_contains "$route" '"hostReasoning":"low"'
assert_contains "$route" '"preferredModel":"gpt-5.3-codex-spark"'
assert_contains "$route" '"displayReasoning":"low"'
assert_contains "$route" '"modelSelectionMode":"TEST_ONLY_ROUTE"'
assert_contains "$route" '"reasoningCeiling":"high"'
assert_contains "$route" '"catalogModelCount":8'
assert_contains "$route" '"generalModelCount":7'
assert_contains "$route" '"spawnAgents":false'

route="$("$selector" --model-catalog "$catalog" --test-model-catalog --code-change)"
assert_contains "$route" '"tier":"T1"'
assert_contains "$route" '"reasoning":"low"'
assert_contains "$route" '"preferredModel":"gpt-5.6-luna"'
assert_contains "$route" '"codeChange":true'
assert_contains "$route" '"spawnAgents":false'
assert_contains "$route" '"noSpawnReason":"NO_INDEPENDENT_WORK"'
assert_contains "$route" '"routeEvidenceRequired":true'

route="$("$selector" --model-catalog "$catalog" --test-model-catalog --code-change --agents-unavailable)"
assert_contains "$route" '"spawnAgents":false'
assert_contains "$route" '"noSpawnReason":"TOOL_UNAVAILABLE"'

route="$("$selector" --model-catalog "$catalog" --test-model-catalog --scope 2 --ambiguity 2 --coupling 1 --risk 1 --verification 1 --delegation-benefit)"
assert_contains "$route" '"tier":"T2"'
assert_contains "$route" '"topology":"lead-plus-sidecar"'

route="$("$selector" --model-catalog "$catalog" --test-model-catalog --risk-floor Payment --delegation-benefit --independent-workstreams 2)"
assert_contains "$route" '"tier":"T4"'
assert_contains "$route" '"reasoning":"medium"'
assert_contains "$route" '"preferredModel":"gpt-5.6-sol"'
assert_contains "$route" '"topology":"lead-workers-independent-verifier"'
assert_contains "$route" '"freshReviewMode":"FRESH_CONTEXT_REQUIRED"'
assert_contains "$route" '"freshReviewRequired":true'

route="$("$selector" --model-catalog "$catalog" --test-model-catalog --risk-floor Authentication)"
assert_contains "$route" '"tier":"T3"'
assert_contains "$route" '"preferredModel":"gpt-5.6-sol"'
assert_contains "$route" '"reasoning":"low"'
assert_contains "$route" '"freshReviewMode":"FRESH_CONTEXT_RECOMMENDED"'

route="$("$selector" --model-catalog "$catalog" --test-model-catalog --risk-floor Authentication --models-unavailable)"
assert_contains "$route" '"preferredModel":null'

route="$("$selector" --model-catalog "$catalog" --test-model-catalog --scope 2 --ambiguity 2 --coupling 1 --risk 1 --verification 1 --delegation-benefit --agents-unavailable)"
assert_contains "$route" '"agentsAvailable":false'
assert_contains "$route" '"spawnAgents":false'

route="$("$selector" --model-catalog "$catalog" --test-model-catalog --scope 2 --ambiguity 2 --coupling 1 --risk 1 --verification 1 --use-current-model --current-model gpt-5.6-luna)"
assert_contains "$route" '"preferredModel":"gpt-5.6-luna"'
assert_contains "$route" '"reasoning":"low"'
assert_contains "$route" '"currentModelConstraintApplied":true'

route="$("$selector" --model-catalog "$catalog" --test-model-catalog --risk-floor Privacy --use-current-model --current-model gpt-5.6-luna --reasoning-override xhigh --allow-exceed --allow-model-constraint-override)"
assert_contains "$route" '"preferredModel":"gpt-5.6-sol"'
assert_contains "$route" '"reasoning":"xhigh"'
assert_contains "$route" '"aboveCeilingAuthorized":true'
assert_contains "$route" '"currentModelConstraintOverridden":true'

if "$selector" --risk 3 >/dev/null 2>&1; then echo 'Risk 3 without floor was accepted' >&2; exit 1; fi
for route in \
  "$("$selector" --model-catalog "$catalog" --test-model-catalog)" \
  "$("$selector" --model-catalog "$catalog" --test-model-catalog --scope 1 --ambiguity 1 --coupling 1 --risk 1 --verification 1)" \
  "$("$selector" --model-catalog "$catalog" --test-model-catalog --risk-floor Authentication)" \
  "$("$selector" --model-catalog "$catalog" --test-model-catalog --risk-floor Privacy)"
do
  printf '%s' "$route" | grep -Eq '"reasoning":"(low|medium|high)"' || { echo "Ordinary route exceeded the low/medium/high ceiling in $route" >&2; exit 1; }
done
capability_routing="$ROOT/framework/58-agent-model-orchestration/02-model-capability-routing.md"
if ! grep -Fq 'economical default, not a hard ceiling' "$capability_routing"; then
  echo 'Model capability routing does not document proportional reasoning.' >&2
  exit 1
fi
echo 'Unix agent route tests passed'
