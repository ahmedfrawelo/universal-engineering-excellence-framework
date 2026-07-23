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
  [switch]$Json
)
$ErrorActionPreference = 'Stop'

$score = $Scope + $Ambiguity + $Coupling + $Risk + $Verification
if ($Risk -eq 3 -and $RiskFloor -eq 'None') {
  throw 'Risk 3 requires an explicit RiskFloor so critical work cannot be downgraded.'
}
$tier = if ($score -le 2) { 'T0' } elseif ($score -le 5) { 'T1' } elseif ($score -le 9) { 'T2' } elseif ($score -le 12) { 'T3' } else { 'T4' }
if ($CodeChange -and $tier -eq 'T0') { $tier = 'T1' }

if ($RiskFloor -in @('Architecture','Authentication','Authorization','Security','Release') -and $tier -in @('T0','T1','T2')) { $tier = 'T3' }
if ($RiskFloor -in @('Production','Migration','Destructive','Privacy','Payment','Incident')) { $tier = 'T4' }

$routes = @{
  T0 = @{ capability='Inherited'; model='inherit'; reasoning='low'; topology='single-agent' }
  T1 = @{ capability='Fast'; model='inherit'; reasoning='medium'; topology='single-agent' }
  T2 = @{ capability='Balanced'; model='inherit'; reasoning='medium'; topology='lead-plus-sidecar' }
  T3 = @{ capability='Frontier'; model='inherit'; reasoning='high'; topology='parallel-specialists' }
  T4 = @{ capability='Frontier'; model='inherit'; reasoning='high'; topology='lead-workers-independent-verifier' }
}
$route = $routes[$tier]
$reasoning = $route.reasoning
$spawnAgents = !$AgentsUnavailable -and ($DelegationBenefit.IsPresent -or $tier -eq 'T4')
$topology = if (!$spawnAgents) {
  'single-agent'
} elseif ($tier -eq 'T2' -or $IndependentWorkstreams -eq 1) {
  if ($tier -eq 'T4') { 'lead-plus-independent-verifier' } else { 'lead-plus-sidecar' }
} else {
  $route.topology
}
$preferredModel = if ($ModelsUnavailable) { $null } else { $route.model }
$noSpawnReason = if ($spawnAgents) { $null } elseif ($CodeChange -and $AgentsUnavailable) { 'TOOL_UNAVAILABLE' } elseif ($tier -in @('T0','T1')) { 'NO_INDEPENDENT_WORK' } else { 'CRITICAL_PATH_ONLY' }
$result = [ordered]@{
  schemaVersion = 4
  score = $score
  riskFloor = $RiskFloor
  tier = $tier
  capability = $route.capability
  preferredModel = $preferredModel
  reasoning = $reasoning
  reasoningCeiling = 'proportional'
  topology = $topology
  delegationBenefit = $DelegationBenefit.IsPresent
  codeChange = $CodeChange.IsPresent
  independentWorkstreams = $IndependentWorkstreams
  agentsAvailable = !$AgentsUnavailable
  spawnAgents = $spawnAgents
  noSpawnReason = $noSpawnReason
  routeEvidenceRequired = $true
  independentVerificationRequired = $tier -eq 'T4'
  modelAvailabilityMustBeVerified = !$ModelsUnavailable -and $route.model -ne 'inherit'
  note = 'Delegation is optional and requires an independent benefit. T0/T1 default to single-agent; models inherit the platform default; T4 requires independent verification.'
}
if ($Json) { $result | ConvertTo-Json -Depth 3 } else { [pscustomobject]$result }
