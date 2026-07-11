#!/usr/bin/env sh
set -eu

scope=0 ambiguity=0 coupling=0 risk=0 verification=0
risk_floor=None code_change=false delegation_benefit=false

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
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

for value in "$scope" "$ambiguity" "$coupling" "$risk" "$verification"; do
  case "$value" in 0|1|2|3) ;; *) echo "Scores must be integers from 0 to 3" >&2; exit 2 ;; esac
done

score=$((scope + ambiguity + coupling + risk + verification))
if [ "$score" -le 2 ]; then tier=T0
elif [ "$score" -le 5 ]; then tier=T1
elif [ "$score" -le 9 ]; then tier=T2
elif [ "$score" -le 12 ]; then tier=T3
else tier=T4
fi

case "$risk_floor" in
  None) ;;
  Architecture|Authentication|Authorization|Security|Release)
    case "$tier" in T0|T1|T2) tier=T3 ;; esac ;;
  Production|Migration|Destructive|Privacy|Payment|Incident) tier=T4 ;;
  *) echo "Unknown risk floor: $risk_floor" >&2; exit 2 ;;
esac

case "$tier" in
  T0) capability=Inherited; model=inherit; reasoning=inherit; routed_topology=single-agent ;;
  T1) capability=Fast; model=gpt-5.6-luna; reasoning=low; routed_topology=single-agent ;;
  T2) capability=Balanced; model=gpt-5.6-terra; reasoning=medium; routed_topology=lead-plus-sidecar ;;
  T3) capability=Frontier; model=gpt-5.6-sol; reasoning=high; routed_topology=parallel-specialists ;;
  T4) capability=Frontier; model=gpt-5.6-sol; reasoning=xhigh; routed_topology=lead-workers-independent-verifier ;;
esac

[ "$tier" = T1 ] && [ "$code_change" = true ] && reasoning=medium
spawn_agents=false
case "$tier" in T2|T3|T4) [ "$delegation_benefit" = true ] && spawn_agents=true ;; esac
if [ "$spawn_agents" = true ]; then topology="$routed_topology"; else topology=single-agent; fi
if [ "$tier" = T4 ]; then independent=true; else independent=false; fi

printf '{"score":%s,"riskFloor":"%s","tier":"%s","capability":"%s","preferredModel":"%s","reasoning":"%s","topology":"%s","delegationBenefit":%s,"spawnAgents":%s,"independentVerificationRequired":%s}\n' \
  "$score" "$risk_floor" "$tier" "$capability" "$model" "$reasoning" "$topology" "$delegation_benefit" "$spawn_agents" "$independent"
