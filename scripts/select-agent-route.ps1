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
  [switch]$Json
)
$ErrorActionPreference = 'Stop'

$score = $Scope + $Ambiguity + $Coupling + $Risk + $Verification
$tier = if ($score -le 2) { 'T0' } elseif ($score -le 5) { 'T1' } elseif ($score -le 9) { 'T2' } elseif ($score -le 12) { 'T3' } else { 'T4' }

if ($RiskFloor -in @('Architecture','Authentication','Authorization','Security','Release') -and $tier -in @('T0','T1','T2')) { $tier = 'T3' }
if ($RiskFloor -in @('Production','Migration','Destructive','Privacy','Payment','Incident')) { $tier = 'T4' }

$routes = @{
  T0 = @{ capability='Inherited'; model='inherit'; reasoning='inherit'; topology='single-agent' }
  T1 = @{ capability='Fast'; model='gpt-5.6-luna'; reasoning='low'; topology='single-agent' }
  T2 = @{ capability='Balanced'; model='gpt-5.6-terra'; reasoning='medium'; topology='lead-plus-sidecar' }
  T3 = @{ capability='Frontier'; model='gpt-5.6-sol'; reasoning='high'; topology='parallel-specialists' }
  T4 = @{ capability='Frontier'; model='gpt-5.6-sol'; reasoning='xhigh'; topology='lead-workers-independent-verifier' }
}
$route = $routes[$tier]
$reasoning = if ($tier -eq 'T1' -and $CodeChange) { 'medium' } else { $route.reasoning }
$spawnAgents = $DelegationBenefit.IsPresent -and $tier -in @('T2','T3','T4')
$topology = if (!$spawnAgents) { 'single-agent' } else { $route.topology }
$result = [ordered]@{
  score = $score
  riskFloor = $RiskFloor
  tier = $tier
  capability = $route.capability
  preferredModel = $route.model
  reasoning = $reasoning
  topology = $topology
  delegationBenefit = $DelegationBenefit.IsPresent
  spawnAgents = $spawnAgents
  independentVerificationRequired = $tier -eq 'T4'
  note = 'Spawn only when delegation benefit is true and the platform exposes agents; T4 still requires independent verification when available.'
}
if ($Json) { $result | ConvertTo-Json -Depth 3 } else { [pscustomobject]$result }
