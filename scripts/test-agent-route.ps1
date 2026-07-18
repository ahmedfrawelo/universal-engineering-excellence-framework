$ErrorActionPreference = 'Stop'
$selector = Join-Path $PSScriptRoot 'select-agent-route.ps1'

function Assert-Route {
  param([hashtable]$Arguments, [hashtable]$Expected)
  $actual = (& $selector @Arguments -Json | ConvertFrom-Json)
  foreach ($key in $Expected.Keys) {
    if ($actual.$key -ne $Expected[$key]) {
      throw "Route assertion failed for $key. Expected '$($Expected[$key])', got '$($actual.$key)'."
    }
  }
}

Assert-Route @{} @{ schemaVersion=3; tier='T0'; reasoning='medium'; reasoningCeiling='medium'; topology='single-agent'; spawnAgents=$false }
Assert-Route @{ CodeChange=$true } @{ tier='T1'; preferredModel='gpt-5.6-luna'; reasoning='medium'; codeChange=$true; spawnAgents=$true; noSpawnReason=$null; routeEvidenceRequired=$true }
Assert-Route @{ Scope=2; Ambiguity=2; Coupling=1; Risk=1; Verification=1 } @{ tier='T2'; topology='single-agent'; spawnAgents=$false }
Assert-Route @{ Scope=2; Ambiguity=2; Coupling=1; Risk=1; Verification=1; DelegationBenefit=$true } @{ tier='T2'; topology='lead-plus-sidecar'; spawnAgents=$true }
Assert-Route @{ RiskFloor='Authentication' } @{ tier='T3'; preferredModel='gpt-5.6-sol' }
Assert-Route @{ RiskFloor='Privacy' } @{ tier='T4'; reasoning='medium'; reasoningCeiling='medium'; independentVerificationRequired=$true }
Assert-Route @{ RiskFloor='Payment'; DelegationBenefit=$true } @{ tier='T4'; topology='lead-plus-independent-verifier'; spawnAgents=$true }
Assert-Route @{ RiskFloor='Payment'; DelegationBenefit=$true; IndependentWorkstreams=2 } @{ tier='T4'; topology='lead-workers-independent-verifier'; spawnAgents=$true }
Assert-Route @{ Scope=3; Ambiguity=3; Coupling=3; Risk=2; Verification=1; DelegationBenefit=$true; IndependentWorkstreams=1 } @{ tier='T3'; topology='lead-plus-sidecar' }
Assert-Route @{ Scope=3; Ambiguity=3; Coupling=3; Risk=2; Verification=1; DelegationBenefit=$true; IndependentWorkstreams=2 } @{ tier='T3'; topology='parallel-specialists' }
Assert-Route @{ Scope=2; Ambiguity=2; Coupling=1; Risk=1; Verification=1; DelegationBenefit=$true; AgentsUnavailable=$true } @{ topology='single-agent'; spawnAgents=$false; agentsAvailable=$false }
Assert-Route @{ CodeChange=$true; AgentsUnavailable=$true } @{ tier='T1'; spawnAgents=$false; agentsAvailable=$false; noSpawnReason='TOOL_UNAVAILABLE'; routeEvidenceRequired=$true }
Assert-Route @{ RiskFloor='Authentication'; ModelsUnavailable=$true } @{ preferredModel=$null; modelAvailabilityMustBeVerified=$false }

$criticalRejected = $false
try { & $selector -Risk 3 -Json | Out-Null } catch { $criticalRejected = $true }
if (!$criticalRejected) { throw 'Risk 3 without RiskFloor must be rejected.' }

$root = Split-Path -Parent $PSScriptRoot
$contractChecks = @{
  'UEEF-LOADER.md' = @('Agent route:', 'TOOL_UNAVAILABLE')
  'framework/58-agent-model-orchestration/00-agent-model-orchestration-system.md' = @('Visible pre-command route line', 'TOOL_UNAVAILABLE')
  'framework/27-quality-gates/31-agent-model-routing-gate.md' = @('TOOL_UNAVAILABLE', 'child-agent record')
  'framework/29-checklists/40-agent-model-routing-checklist.md' = @('Visible pre-command route line', 'Child agent identity', 'TOOL_UNAVAILABLE')
  'framework/38-templates/28-agent-routing-decision-template.md' = @('Visible pre-command route line', 'Child agent identity', 'TOOL_UNAVAILABLE')
  'scripts/sync-runtime.ps1' = @('Agent route:', 'TOOL_UNAVAILABLE', 'Never claim UEEF routing')
}
foreach ($relativePath in $contractChecks.Keys) {
  $content = Get-Content -LiteralPath (Join-Path $root $relativePath) -Raw
  foreach ($term in $contractChecks[$relativePath]) {
    if ($content -notmatch [regex]::Escape($term)) { throw "Agent contract term '$term' missing from $relativePath." }
  }
}
$topologyText = Get-Content -LiteralPath (Join-Path $root 'framework/58-agent-model-orchestration/03-agent-topologies.md') -Raw
if ($topologyText -match 'most T1 tasks') { throw 'Topology policy still permits silent single-agent code-changing T1 work.' }

foreach ($routeArgs in @(@{}, @{Scope=1;Ambiguity=1;Coupling=1;Risk=1;Verification=1}, @{RiskFloor='Authentication'}, @{RiskFloor='Privacy'})) {
  $route = & $selector @routeArgs -Json | ConvertFrom-Json
  if ($route.reasoning -notin @('low','medium')) { throw "Reasoning ceiling exceeded: $($route.reasoning)" }
}

$bashPath = if (Test-Path 'C:\Program Files\Git\bin\bash.exe') { 'C:\Program Files\Git\bin\bash.exe' } else { '' }
if ($bashPath) {
  $psRoute = & $selector -RiskFloor Payment -DelegationBenefit -IndependentWorkstreams 2 -Json | ConvertFrom-Json
  $shSelector = (Join-Path $PSScriptRoot 'select-agent-route.sh').Replace('\','/')
  $shRoute = & $bashPath $shSelector --risk-floor Payment --delegation-benefit --independent-workstreams 2 | ConvertFrom-Json
  $psProperties = @($psRoute.psobject.Properties.Name | Sort-Object)
  $shProperties = @($shRoute.psobject.Properties.Name | Sort-Object)
  if (($psProperties -join '|') -ne ($shProperties -join '|')) { throw 'PowerShell and Unix route schemas differ.' }
  foreach ($property in $psProperties) {
    if ([string]$psRoute.$property -ne [string]$shRoute.$property) { throw "PowerShell and Unix route values differ for $property." }
  }
}

$capabilityRouting = Get-Content -LiteralPath (Join-Path $root 'framework\58-agent-model-orchestration\02-model-capability-routing.md') -Raw
if ($capabilityRouting -match '\|\s*T[0-4]\s*\|[^\r\n]*\|\s*(high|xhigh|max|ultra)\s*\|') {
  throw 'Model capability routing exceeds the medium reasoning ceiling.'
}

Write-Host 'Agent route tests passed'
