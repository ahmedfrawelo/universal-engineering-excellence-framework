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

Assert-Route @{} @{ tier='T0'; topology='single-agent'; spawnAgents=$false }
Assert-Route @{ Scope=1; Ambiguity=1; Coupling=1; Risk=1; Verification=1; CodeChange=$true } @{ tier='T1'; preferredModel='gpt-5.6-luna'; reasoning='medium' }
Assert-Route @{ Scope=2; Ambiguity=2; Coupling=1; Risk=1; Verification=1 } @{ tier='T2'; topology='single-agent'; spawnAgents=$false }
Assert-Route @{ Scope=2; Ambiguity=2; Coupling=1; Risk=1; Verification=1; DelegationBenefit=$true } @{ tier='T2'; topology='lead-plus-sidecar'; spawnAgents=$true }
Assert-Route @{ RiskFloor='Authentication' } @{ tier='T3'; preferredModel='gpt-5.6-sol' }
Assert-Route @{ RiskFloor='Privacy' } @{ tier='T4'; independentVerificationRequired=$true }
Assert-Route @{ RiskFloor='Payment'; DelegationBenefit=$true } @{ tier='T4'; topology='lead-plus-independent-verifier'; spawnAgents=$true }
Assert-Route @{ RiskFloor='Payment'; DelegationBenefit=$true; IndependentWorkstreams=2 } @{ tier='T4'; topology='lead-workers-independent-verifier'; spawnAgents=$true }
Assert-Route @{ Scope=3; Ambiguity=3; Coupling=3; Risk=2; Verification=1; DelegationBenefit=$true; IndependentWorkstreams=1 } @{ tier='T3'; topology='lead-plus-sidecar' }
Assert-Route @{ Scope=3; Ambiguity=3; Coupling=3; Risk=2; Verification=1; DelegationBenefit=$true; IndependentWorkstreams=2 } @{ tier='T3'; topology='parallel-specialists' }
Assert-Route @{ Scope=2; Ambiguity=2; Coupling=1; Risk=1; Verification=1; DelegationBenefit=$true; AgentsUnavailable=$true } @{ topology='single-agent'; spawnAgents=$false; agentsAvailable=$false }
Assert-Route @{ RiskFloor='Authentication'; ModelsUnavailable=$true } @{ preferredModel=$null; modelAvailabilityMustBeVerified=$false }

$criticalRejected = $false
try { & $selector -Risk 3 -Json | Out-Null } catch { $criticalRejected = $true }
if (!$criticalRejected) { throw 'Risk 3 without RiskFloor must be rejected.' }

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

Write-Host 'Agent route tests passed'
