#!/usr/bin/env sh
set -eu

scope=0 ambiguity=0 coupling=0 risk=0 verification=0
risk_floor=None code_change=false delegation_benefit=false independent_workstreams=1
delegation_authorized=false delegation_authorization_source=NONE execution_mode=Auto
agents_available=true models_available=true
model_policy="" model_catalog="" test_model_catalog=false
use_current_model=false current_model="" reasoning_override="" allow_exceed=false allow_model_constraint_override=false
work_unit_id=default-work-unit specialist_purpose="" invocation_index=0

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
    --delegation-authorized) delegation_authorized=true; shift ;;
    --delegation-authorization-source) delegation_authorization_source="$2"; shift 2 ;;
    --execution-mode) execution_mode="$2"; shift 2 ;;
    --independent-workstreams) independent_workstreams="$2"; shift 2 ;;
    --agents-unavailable) agents_available=false; shift ;;
    --models-unavailable) models_available=false; shift ;;
    --model-policy) model_policy="$2"; shift 2 ;;
    --model-catalog) model_catalog="$2"; shift 2 ;;
    --test-model-catalog) test_model_catalog=true; shift ;;
    --use-current-model) use_current_model=true; shift ;;
    --current-model) current_model="$2"; shift 2 ;;
    --reasoning-override) reasoning_override="$2"; shift 2 ;;
    --allow-exceed) allow_exceed=true; shift ;;
    --allow-model-constraint-override) allow_model_constraint_override=true; shift ;;
    --work-unit-id) work_unit_id="$2"; shift 2 ;;
    --specialist-purpose) specialist_purpose="$2"; shift 2 ;;
    --invocation-index) invocation_index="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done
case "$delegation_authorization_source" in NONE|USER|PLATFORM_POLICY|TASK_INSTRUCTION) ;; *) echo "Unknown delegation authorization source: $delegation_authorization_source" >&2; exit 2 ;; esac
case "$execution_mode" in Auto|Review|Implementation) ;; *) echo "Execution mode must be Auto, Review, or Implementation" >&2; exit 2 ;; esac
if { [ "$delegation_authorized" = true ] && [ "$delegation_authorization_source" = NONE ]; } || { [ "$delegation_authorized" = false ] && [ "$delegation_authorization_source" != NONE ]; }; then
  echo "Delegation authorization requires both --delegation-authorized and a non-NONE --delegation-authorization-source" >&2
  exit 2
fi
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
  T0) routed_topology=single-agent ;;
  T1) routed_topology=single-agent ;;
  T2) routed_topology=lead-plus-sidecar ;;
  T3) routed_topology=parallel-specialists ;;
  T4) routed_topology=lead-workers-independent-verifier ;;
esac

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
[ -n "$model_policy" ] || model_policy="$ROOT/config/model-routing-policy.json"
set -- --tier "$tier" --policy "$model_policy"
set -- "$@" --work-unit-id "$work_unit_id"
set -- "$@" --invocation-index "$invocation_index"
[ -n "$model_catalog" ] && set -- "$@" --catalog "$model_catalog"
[ "$test_model_catalog" = true ] && set -- "$@" --allow-test-catalog
[ "$models_available" = false ] && set -- "$@" --models-unavailable
[ "$use_current_model" = true ] && set -- "$@" --use-current-model --current-model "$current_model"
[ -n "$reasoning_override" ] && set -- "$@" --reasoning-override "$reasoning_override"
[ "$allow_exceed" = true ] && set -- "$@" --allow-exceed
[ "$allow_model_constraint_override" = true ] && set -- "$@" --allow-model-constraint-override
[ -n "$specialist_purpose" ] && set -- "$@" --specialist-purpose "$specialist_purpose"
model_route=$(node "$ROOT/scripts/resolve-model-route.mjs" "$@")

delegation_requested=false
if [ "$delegation_benefit" = true ] || [ "$tier" = T4 ]; then delegation_requested=true; fi
delegation_authorization_valid=false
if [ "$delegation_authorized" = true ] && [ "$delegation_authorization_source" != NONE ]; then delegation_authorization_valid=true; fi
if [ "$delegation_authorization_valid" = false ]; then delegation_scope=NONE
elif [ "$delegation_authorization_source" = PLATFORM_POLICY ]; then delegation_scope=INDEPENDENT_VERIFIER
else delegation_scope=WORKERS
fi
spawn_agents=false
if [ "$agents_available" = true ] && [ "$delegation_requested" = true ] && [ "$delegation_authorization_valid" = true ]; then spawn_agents=true; fi
if [ "$spawn_agents" = false ]; then topology=single-agent
elif [ "$delegation_authorization_source" = PLATFORM_POLICY ]; then topology=lead-plus-independent-verifier
elif [ "$tier" = T4 ] && [ "$independent_workstreams" -eq 1 ]; then topology=lead-plus-independent-verifier
elif [ "$tier" = T2 ] || [ "$independent_workstreams" -eq 1 ]; then topology=lead-plus-sidecar
else topology="$routed_topology"
fi
if [ "$tier" = T4 ]; then independent=true; else independent=false; fi
if [ "$tier" = T4 ]; then fresh_review_mode=FRESH_CONTEXT_REQUIRED; fresh_review_required=true
elif [ "$tier" = T3 ]; then fresh_review_mode=FRESH_CONTEXT_RECOMMENDED; fresh_review_required=false
else fresh_review_mode=NONE; fresh_review_required=false
fi
if [ "$spawn_agents" = true ]; then no_spawn_reason=null
elif [ "$delegation_requested" = true ] && [ "$agents_available" = false ]; then no_spawn_reason='"TOOL_UNAVAILABLE"'
elif [ "$delegation_requested" = true ] && [ "$delegation_authorization_valid" = false ]; then no_spawn_reason='"AUTHORIZATION_REQUIRED"'
elif [ "$tier" = T0 ] || [ "$tier" = T1 ]; then no_spawn_reason='"NO_INDEPENDENT_WORK"'
else no_spawn_reason='"CRITICAL_PATH_ONLY"'
fi
if [ "$execution_mode" = Auto ]; then if [ "$code_change" = true ]; then resolved_execution_mode=IMPLEMENTATION; else resolved_execution_mode=REVIEW; fi
else resolved_execution_mode=$(printf '%s' "$execution_mode" | tr '[:lower:]' '[:upper:]'); fi
case "$tier" in T0|T1) spec_mode=NONE; spec_reason=TIER_DOES_NOT_REQUIRE_SPEC ;; T2) spec_mode=LIGHT; spec_reason=EXECUTION_SPEC_REQUIRED ;; *) spec_mode=FULL_REQUIRED; spec_reason=FULL_SPEC_REQUIRED_BY_SCOPE_OR_RISK ;; esac
if [ "$spawn_agents" = true ]; then team_mode=SPAWN; team_reason=AUTHORIZED_POSITIVE_DELEGATION_BENEFIT
elif [ "$no_spawn_reason" = '"AUTHORIZATION_REQUIRED"' ]; then team_mode=AUTHORIZATION_REQUIRED; team_reason=AUTHORIZATION_REQUIRED
else team_mode=NONE; team_reason=$(printf '%s' "$no_spawn_reason" | tr -d '"'); fi
printf '%s' "$model_route" | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  const r=JSON.parse(s), meta=JSON.parse(process.argv[1]);
  const out={schemaVersion:4,score:meta.score,riskFloor:meta.riskFloor,tier:meta.tier,capability:r.capability,preferredModel:r.preferredModel,reasoning:r.reasoning,displayReasoning:r.displayReasoning,hostReasoning:r.hostReasoning,modelSelectionMode:r.modelSelectionMode,fallbackModel:r.fallbackModel,fallbackReasoning:r.fallbackReasoning,fallbackDisplayReasoning:r.fallbackDisplayReasoning,fallbackHostReasoning:r.fallbackHostReasoning,modelAvailability:r.modelAvailability,accountRotationAllowed:r.accountRotationAllowed===true,accountCatalogVerified:r.accountCatalogVerified===true,testCatalogAllowed:r.testCatalogAllowed===true,catalogProvider:r.catalogProvider,eligibleSelectionPool:r.eligibleSelectionPool,selectionPoolSize:r.selectionPoolSize,distributionKey:r.distributionKey,distributionIndex:r.distributionIndex,specialistPurpose:r.specialistPurpose,invocationIndex:r.invocationIndex,effortRotation:r.effortRotation,catalogDiscoveredAt:r.catalogDiscoveredAt,catalogFresh:r.catalogFresh===true,catalogContractValid:r.catalogContractValid===true,catalogModelCount:r.catalogModelCount,generalModelCount:r.generalModelCount,catalogCoverage:r.catalogCoverage,catalogDigest:r.catalogDigest,reasoningCeiling:r.reasoningCeiling,aboveCeilingAuthorized:r.aboveCeilingAuthorized===true,requestedCurrentModel:r.requestedCurrentModel,currentModelConstraintApplied:r.currentModelConstraintApplied===true,currentModelConstraintOverridden:r.currentModelConstraintOverridden===true,topology:meta.topology,mode:meta.mode,spec:meta.spec,specReason:meta.specReason,team:meta.team,teamReason:meta.teamReason,delegationBenefit:meta.delegationBenefit,delegationAuthorized:meta.delegationAuthorized,delegationAuthorizationSource:meta.delegationAuthorizationSource,delegationScope:meta.delegationScope,codeChange:meta.codeChange,independentWorkstreams:meta.independentWorkstreams,agentsAvailable:meta.agentsAvailable,spawnAgents:meta.spawnAgents,noSpawnReason:meta.noSpawnReason,routeEvidenceRequired:true,independentVerificationRequired:meta.independent,freshReviewMode:meta.freshReviewMode,freshReviewRequired:meta.freshReviewRequired,modelAvailabilityMustBeVerified:r.accountCatalogVerified===true,note:"Routing and verification stay proportional to tier and risk. Discover the signed-in account catalog through the current host first and Codex App Server model/list when available, then run the selected model and exact host effort. Display the host-provided effort name without a repository rename. The policy ceiling is high unless the user explicitly authorizes an override. On provider capacity, attempt the declared fallback once without rotating accounts."};
  process.stdout.write(JSON.stringify(out)+"\n");
});' "$(node -e 'process.stdout.write(JSON.stringify({score:Number(process.argv[1]),riskFloor:process.argv[2],tier:process.argv[3],topology:process.argv[4],mode:process.argv[5],spec:process.argv[6],specReason:process.argv[7],team:process.argv[8],teamReason:process.argv[9],delegationBenefit:process.argv[10]==="true",delegationAuthorized:process.argv[11]==="true",delegationAuthorizationSource:process.argv[12],delegationScope:process.argv[13],codeChange:process.argv[14]==="true",independentWorkstreams:Number(process.argv[15]),agentsAvailable:process.argv[16]==="true",spawnAgents:process.argv[17]==="true",noSpawnReason:process.argv[18]==="null"?null:process.argv[18],independent:process.argv[19]==="true",freshReviewMode:process.argv[20],freshReviewRequired:process.argv[21]==="true"}))' "$score" "$risk_floor" "$tier" "$topology" "$resolved_execution_mode" "$spec_mode" "$spec_reason" "$team_mode" "$team_reason" "$delegation_benefit" "$delegation_authorization_valid" "$([ "$delegation_authorization_valid" = true ] && printf '%s' "$delegation_authorization_source" || printf NONE)" "$delegation_scope" "$code_change" "$independent_workstreams" "$agents_available" "$spawn_agents" "$(printf '%s' "$no_spawn_reason" | tr -d '"')" "$independent" "$fresh_review_mode" "$fresh_review_required")"
