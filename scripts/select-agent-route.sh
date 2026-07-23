#!/usr/bin/env sh
set -eu

scope=0 ambiguity=0 coupling=0 risk=0 verification=0
risk_floor=None code_change=false delegation_benefit=false independent_workstreams=1
agents_available=true models_available=true

while [ "$#" -gt 0 ]; do
  case "$1" in
    --scope) scope="$2"; shift 2 ;;
    --ambiguity) ambiguity="$2"; shift 2 ;;
    --coupling) coupling="$2"; shift 2 ;;
    --risk) risk="$2"; shift 2 ;;
    --verification) verification="$2"; shift 2 ;;
    --risk-floor) risk_floor="$2"; shift 2 ;;
    --code-change) code_change=true; shift ;;
    --delegation-benefit) delegation_benefit=true; shift ;;
    --independent-workstreams) independent_workstreams="$2"; shift 2 ;;
    --agents-unavailable) agents_available=false; shift ;;
    --models-unavailable) models_available=false; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done
case "$independent_workstreams" in ''|*[!0-9]*) echo "Independent workstreams must be an integer from 1 to 16" >&2; exit 2 ;; esac
[ "$independent_workstreams" -ge 1 ] && [ "$independent_workstreams" -le 16 ] || { echo "Independent workstreams must be an integer from 1 to 16" >&2; exit 2; }

for value in "$scope" "$ambiguity" "$coupling" "$risk" "$verification"; do
  case "$value" in 0|1|2|3) ;; *) echo "Scores must be integers from 0 to 3" >&2; exit 2 ;; esac
done

score=$((scope + ambiguity + coupling + risk + verification))
[ "$risk" -eq 3 ] && [ "$risk_floor" = None ] && { echo "Risk 3 requires an explicit risk floor" >&2; exit 2; }
if [ "$score" -le 2 ]; then tier=T0
elif [ "$score" -le 5 ]; then tier=T1
elif [ "$score" -le 9 ]; then tier=T2
elif [ "$score" -le 12 ]; then tier=T3
else tier=T4
fi
[ "$code_change" = true ] && [ "$tier" = T0 ] && tier=T1

case "$risk_floor" in
  None) ;;
  Architecture|Authentication|Authorization|Security|Release)
    case "$tier" in T0|T1|T2) tier=T3 ;; esac ;;
  Production|Migration|Destructive|Privacy|Payment|Incident) tier=T4 ;;
  *) echo "Unknown risk floor: $risk_floor" >&2; exit 2 ;;
esac

case "$tier" in
  T0) capability=Inherited; model=inherit; reasoning=medium; routed_topology=single-agent ;;
  T1) capability=Fast; model=gpt-5.6-luna; reasoning=low; routed_topology=single-agent ;;
  T2) capability=Balanced; model=gpt-5.6-terra; reasoning=medium; routed_topology=lead-plus-sidecar ;;
  T3) capability=Frontier; model=gpt-5.6-sol; reasoning=medium; routed_topology=parallel-specialists ;;
  T4) capability=Frontier; model=gpt-5.6-sol; reasoning=medium; routed_topology=lead-workers-independent-verifier ;;
esac

[ "$tier" = T1 ] && [ "$code_change" = true ] && reasoning=medium
spawn_agents=false
if [ "$agents_available" = true ] && { [ "$delegation_benefit" = true ] || [ "$tier" = T4 ]; }; then spawn_agents=true; fi
if [ "$spawn_agents" = false ]; then topology=single-agent
elif [ "$tier" = T4 ] && [ "$independent_workstreams" -eq 1 ]; then topology=lead-plus-independent-verifier
elif [ "$tier" = T2 ] || [ "$independent_workstreams" -eq 1 ]; then topology=lead-plus-sidecar
else topology="$routed_topology"
fi
if [ "$tier" = T4 ]; then independent=true; else independent=false; fi
if [ "$spawn_agents" = true ]; then no_spawn_reason=null
elif [ "$code_change" = true ] && [ "$agents_available" = false ]; then no_spawn_reason='"TOOL_UNAVAILABLE"'
elif [ "$tier" = T0 ] || [ "$tier" = T1 ]; then no_spawn_reason='"NO_INDEPENDENT_WORK"'
else no_spawn_reason='"CRITICAL_PATH_ONLY"'
fi
if [ "$models_available" = false ]; then model_json=null; model_verify=false
else model_json="\"$model\""; if [ "$model" = inherit ]; then model_verify=false; else model_verify=true; fi
fi

printf '{"schemaVersion":3,"score":%s,"riskFloor":"%s","tier":"%s","capability":"%s","preferredModel":%s,"reasoning":"%s","reasoningCeiling":"medium","topology":"%s","delegationBenefit":%s,"codeChange":%s,"independentWorkstreams":%s,"agentsAvailable":%s,"spawnAgents":%s,"noSpawnReason":%s,"routeEvidenceRequired":true,"independentVerificationRequired":%s,"modelAvailabilityMustBeVerified":%s,"note":"Delegation is optional and requires an independent benefit. T1 defaults to single-agent; T4 requires independent verification."}\n' \
  "$score" "$risk_floor" "$tier" "$capability" "$model_json" "$reasoning" "$topology" "$delegation_benefit" "$code_change" "$independent_workstreams" "$agents_available" "$spawn_agents" "$no_spawn_reason" "$independent" "$model_verify"
