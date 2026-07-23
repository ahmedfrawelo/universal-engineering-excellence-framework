$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Require-Term([string]$RelativePath, [string]$Term) {
  $text = Get-Content -LiteralPath (Join-Path $root $RelativePath) -Raw
  if ($text -notmatch [regex]::Escape($Term)) { throw "Intent-fidelity term '$Term' missing from $RelativePath." }
}

foreach ($relative in @('UEEF-LOADER.md', 'framework/01-core/00-core-system.md', 'framework/01-core/13-autonomy-and-confirmation-policy.md')) {
  Require-Term $relative 'Scope wins'
}
Require-Term 'framework/01-core/14-delivery-continuation-policy.md' 'Stop When Done'
Require-Term 'framework/58-agent-model-orchestration/02-model-capability-routing.md' 'economical default, not a hard ceiling'
Require-Term 'UEEF-LOADER.md' 'Never turn a T0/T1 request into an autonomous inventory or upgrade.'
Require-Term 'framework/01-core/00-core-system.md' 'Do not turn T0/T1 work into an autonomous upgrade or inventory.'
Require-Term 'framework/01-core/01-master-loader.md' 'mere mention of a browser'

$activeContracts = @(
  'UEEF-LOADER.md',
  'framework/01-core/01-master-loader.md',
  'framework/58-agent-model-orchestration/00-agent-model-orchestration-system.md',
  'framework/27-quality-gates/31-agent-model-routing-gate.md',
  'scripts/select-agent-route.ps1',
  'scripts/select-agent-route.sh'
) | ForEach-Object { Get-Content -LiteralPath (Join-Path $root $_) -Raw }
if (($activeContracts -join "`n") -match 'For every non-trivial T1-T4 code change, spawn at least one bounded child|only valid no-spawn reason') {
  throw 'An absolute T1 child-spawn contract remains.'
}

$profile = & (Join-Path $PSScriptRoot 'select-capability-profile.ps1') -Task 'Document the browser policy in this repository' -Json | ConvertFrom-Json
if ($profile.mcps -contains 'node_repl') { throw 'A casual browser mention still selects browser control.' }

Write-Host 'Intent fidelity contract tests passed'
