param(
  [ValidateRange(0,3)][int]$Scope = 0,
  [ValidateRange(0,3)][int]$Ambiguity = 0,
  [ValidateRange(0,3)][int]$Coupling = 0,
  [ValidateRange(0,3)][int]$Risk = 0,
  [ValidateRange(0,3)][int]$Verification = 0,
  [ValidateSet('None','Architecture','Authentication','Authorization','Security','Production','Migration','Destructive','Privacy','Payment','Incident','Release')]
  [string]$RiskFloor = 'None',
  [switch]$CodeChange,
  [switch]$DelegationBenefit,
  [ValidateRange(1,16)][int]$IndependentWorkstreams = 1,
  [switch]$AgentsUnavailable,
  [switch]$ModelsUnavailable,
  [string]$ModelPolicyPath,
  [string]$ModelCatalogPath,
  [switch]$TestModelCatalog,
  [switch]$UseCurrentModel,
  [string]$CurrentModel,
  [string]$ReasoningOverride,
  [switch]$AllowExceed,
  [switch]$AllowModelConstraintOverride,
  [string]$WorkUnitId = 'default-work-unit',
  [string]$SpecialistPurpose,
  [ValidateRange(0,2147483647)][int]$InvocationIndex = 0,
  [switch]$Json
)
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ModelPolicyPath)) { $ModelPolicyPath = Join-Path $root 'config\model-routing-policy.json' }

$score = $Scope + $Ambiguity + $Coupling + $Risk + $Verification
if ($Risk -eq 3 -and $RiskFloor -eq 'None') {
  throw 'Risk 3 requires an explicit RiskFloor so critical work cannot be downgraded.'
}
$tier = if ($score -le 2) { 'T0' } elseif ($score -le 5) { 'T1' } elseif ($score -le 9) { 'T2' } elseif ($score -le 12) { 'T3' } else { 'T4' }
if ($CodeChange -and $tier -eq 'T0') { $tier = 'T1' }

if ($RiskFloor -in @('Architecture','Authentication','Authorization','Security','Release') -and $tier -in @('T0','T1','T2')) { $tier = 'T3' }
if ($RiskFloor -in @('Production','Migration','Destructive','Privacy','Payment','Incident')) { $tier = 'T4' }

$topologies = @{
  T0 = 'single-agent'
  T1 = 'single-agent'
  T2 = 'lead-plus-sidecar'
  T3 = 'parallel-specialists'
  T4 = 'lead-workers-independent-verifier'
}
$modelPolicy = Get-Content -LiteralPath $ModelPolicyPath -Raw | ConvertFrom-Json
if ($modelPolicy.schemaVersion -ne 3 -or $modelPolicy.adapter -ne 'codex-host-routing' -or $null -eq $modelPolicy.tiers.$tier) {
  throw "Unsupported model routing policy: $ModelPolicyPath"
}
$resolverArgs = @((Join-Path $PSScriptRoot 'resolve-model-route.mjs'), '--tier', $tier, '--policy', $ModelPolicyPath)
$resolverArgs += @('--work-unit-id', $WorkUnitId)
$resolverArgs += @('--invocation-index', $InvocationIndex)
if ($ModelCatalogPath) { $resolverArgs += @('--catalog', $ModelCatalogPath) }
if ($TestModelCatalog) { $resolverArgs += '--allow-test-catalog' }
if ($ModelsUnavailable) { $resolverArgs += '--models-unavailable' }
if ($UseCurrentModel) { $resolverArgs += @('--use-current-model', '--current-model', $CurrentModel) }
if ($ReasoningOverride) { $resolverArgs += @('--reasoning-override', $ReasoningOverride) }
if ($AllowExceed) { $resolverArgs += '--allow-exceed' }
if ($AllowModelConstraintOverride) { $resolverArgs += '--allow-model-constraint-override' }
if ($SpecialistPurpose) { $resolverArgs += @('--specialist-purpose', $SpecialistPurpose) }
$modelRoute = & node @resolverArgs | ConvertFrom-Json
$reasoning = $modelRoute.reasoning
$spawnAgents = !$AgentsUnavailable -and ($DelegationBenefit.IsPresent -or $tier -eq 'T4')
$topology = if (!$spawnAgents) {
  'single-agent'
} elseif ($tier -eq 'T2' -or $IndependentWorkstreams -eq 1) {
  if ($tier -eq 'T4') { 'lead-plus-independent-verifier' } else { 'lead-plus-sidecar' }
} else {
  $topologies[$tier]
}
$preferredModel = $modelRoute.preferredModel
$noSpawnReason = if ($spawnAgents) { $null } elseif ($CodeChange -and $AgentsUnavailable) { 'TOOL_UNAVAILABLE' } elseif ($tier -in @('T0','T1')) { 'NO_INDEPENDENT_WORK' } else { 'CRITICAL_PATH_ONLY' }
$freshReviewMode = if ($tier -eq 'T4') { 'FRESH_CONTEXT_REQUIRED' } elseif ($tier -eq 'T3') { 'FRESH_CONTEXT_RECOMMENDED' } else { 'NONE' }
$result = [ordered]@{
  schemaVersion = 4
  score = $score
  riskFloor = $RiskFloor
  tier = $tier
  capability = $modelRoute.capability
  preferredModel = $preferredModel
  reasoning = $reasoning
  displayReasoning = $modelRoute.displayReasoning
  hostReasoning = $modelRoute.hostReasoning
  modelSelectionMode = $modelRoute.modelSelectionMode
  fallbackModel = $modelRoute.fallbackModel
  fallbackReasoning = $modelRoute.fallbackReasoning
  fallbackDisplayReasoning = $modelRoute.fallbackDisplayReasoning
  fallbackHostReasoning = $modelRoute.fallbackHostReasoning
  modelAvailability = $modelRoute.modelAvailability
  accountRotationAllowed = $modelRoute.accountRotationAllowed
  accountCatalogVerified = $modelRoute.accountCatalogVerified
  testCatalogAllowed = $modelRoute.testCatalogAllowed
  catalogProvider = $modelRoute.catalogProvider
  eligibleSelectionPool = $modelRoute.eligibleSelectionPool
  selectionPoolSize = $modelRoute.selectionPoolSize
  distributionKey = $modelRoute.distributionKey
  distributionIndex = $modelRoute.distributionIndex
  specialistPurpose = $modelRoute.specialistPurpose
  invocationIndex = $modelRoute.invocationIndex
  effortRotation = $modelRoute.effortRotation
  catalogDiscoveredAt = $modelRoute.catalogDiscoveredAt
  catalogFresh = $modelRoute.catalogFresh
  catalogContractValid = $modelRoute.catalogContractValid
  catalogModelCount = $modelRoute.catalogModelCount
  generalModelCount = $modelRoute.generalModelCount
  catalogCoverage = $modelRoute.catalogCoverage
  catalogDigest = $modelRoute.catalogDigest
  reasoningCeiling = $modelRoute.reasoningCeiling
  aboveCeilingAuthorized = $modelRoute.aboveCeilingAuthorized
  requestedCurrentModel = $modelRoute.requestedCurrentModel
  currentModelConstraintApplied = $modelRoute.currentModelConstraintApplied
  currentModelConstraintOverridden = $modelRoute.currentModelConstraintOverridden
  topology = $topology
  delegationBenefit = $DelegationBenefit.IsPresent
  codeChange = $CodeChange.IsPresent
  independentWorkstreams = $IndependentWorkstreams
  agentsAvailable = !$AgentsUnavailable
  spawnAgents = $spawnAgents
  noSpawnReason = $noSpawnReason
  routeEvidenceRequired = $true
  independentVerificationRequired = $tier -eq 'T4'
  freshReviewMode = $freshReviewMode
  freshReviewRequired = $tier -eq 'T4'
  modelAvailabilityMustBeVerified = $modelRoute.accountCatalogVerified -eq $true
  note = 'Routing and verification stay proportional to tier and risk. Discover the signed-in account catalog through the current host first and Codex App Server model/list when available, then run the selected model and exact host effort. Display the host-provided effort name without a repository rename. The policy ceiling is high unless the user explicitly authorizes an override. On provider capacity, attempt the declared fallback once without rotating accounts.'
}
if ($Json) { $result | ConvertTo-Json -Depth 3 } else { [pscustomobject]$result }
