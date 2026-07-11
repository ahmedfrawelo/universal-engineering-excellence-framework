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
Assert-Route @{ RiskFloor='Payment'; DelegationBenefit=$true } @{ tier='T4'; topology='lead-workers-independent-verifier'; spawnAgents=$true }

Write-Host 'Agent route tests passed'
