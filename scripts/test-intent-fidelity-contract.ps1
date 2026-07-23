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
Require-Term 'framework/58-agent-model-orchestration/00-agent-model-orchestration-system.md' 'economical default, not a hard ceiling'
Require-Term 'framework/58-agent-model-orchestration/00-agent-model-orchestration-system.md' 'A single-agent T1 route with `NO_INDEPENDENT_WORK` needs no child-agent evidence.'
Require-Term 'framework/01-core/01-master-loader.md' '`medium` is the economical reasoning default.'
Require-Term 'UEEF-LOADER.md' 'Never turn a T0/T1 request into an autonomous inventory or upgrade.'
Require-Term 'framework/01-core/00-core-system.md' 'Do not turn T0/T1 work into an autonomous upgrade or inventory.'
Require-Term 'framework/01-core/01-master-loader.md' 'mere mention of a browser'
Require-Term 'UEEF-LOADER.md' 'Ask/Do mode'
Require-Term 'UEEF-LOADER.md' 'Intent: <requested outcome> | Tier: <T0-T4>'
Require-Term 'framework/01-core/01-master-loader.md' 'T0/T1 work uses only a focused relevant check'
Require-Term 'examples/intent-fidelity-fixtures.md' 'Change this one validation message.'
Require-Term 'examples/intent-fidelity-fixtures.md' 'Agent route: T1 | Agent: not spawned - NO_INDEPENDENT_WORK'
Require-Term 'QUICK_START.md' 'sync-runtime.ps1'
Require-Term 'QUICK_START.md' 'strict-scope'
Require-Term 'QUICK_START.md' 'master loader/runtime is likely old'
Require-Term 'QUICK_START.md' 'Intent-fidelity regressions run on both validation paths'
Require-Term 'QUICK_START.md' 'test-intent-fidelity-contract.sh'

$activeContracts = @(
  'UEEF-LOADER.md',
  'framework/01-core/01-master-loader.md',
  'framework/58-agent-model-orchestration/00-agent-model-orchestration-system.md',
  'framework/27-quality-gates/31-agent-model-routing-gate.md',
  'scripts/select-agent-route.ps1',
  'scripts/select-agent-route.sh'
) | ForEach-Object { Get-Content -LiteralPath (Join-Path $root $_) -Raw }
if (($activeContracts -join "`n") -match 'For every non-trivial T1-T4 code change, spawn at least one bounded child|only valid no-spawn reason|No route may emit or request a higher level|reasoning ceiling is `medium`|Cap every requested.*medium|never request a reasoning level above medium') {
  throw 'An absolute T1 child-spawn contract remains.'
}

$t1Route = & (Join-Path $PSScriptRoot 'select-agent-route.ps1') -CodeChange -Json | ConvertFrom-Json
if ($t1Route.tier -ne 'T1' -or $t1Route.spawnAgents -or $t1Route.noSpawnReason -ne 'NO_INDEPENDENT_WORK') {
  throw 'A narrow T1 route no longer proves the documented single-agent fixture.'
}

$preflight = Join-Path $PSScriptRoot 'get-ueef-task-preflight.ps1'
$intentFixtures = @(
  @{ name='explain'; task='Explain dependency injection'; codeChange=$false; expectedTier='T0' },
  @{ name='one-file-edit'; task='Change exactly one validation message in one file'; codeChange=$true; expectedTier='T1' },
  @{ name='strict-scope'; task='Do not expand scope; update this one file only'; codeChange=$true; expectedTier='T1' }
)
foreach ($fixture in $intentFixtures) {
  $result = (& $preflight -Task $fixture.task -CodeChange:$fixture.codeChange -SkipHealth -Json | Out-String) | ConvertFrom-Json
  if ($result.classification.route.tier -ne $fixture.expectedTier -or $null -ne $result.browserGate -or $result.profile.mcps -contains 'node_repl') {
    throw "Intent fixture '$($fixture.name)' selected an unexpected route or browser capability."
  }
  if ($fixture.codeChange -and ($result.classification.route.spawnAgents -or $result.classification.route.noSpawnReason -ne 'NO_INDEPENDENT_WORK')) {
    throw "Intent fixture '$($fixture.name)' no longer stays on the single-agent T1 route."
  }
}

$profile = & (Join-Path $PSScriptRoot 'select-capability-profile.ps1') -Task 'Document the browser policy in this repository' -Json | ConvertFrom-Json
if ($profile.mcps -contains 'node_repl') { throw 'A casual browser mention still selects browser control.' }

Write-Host 'Intent fidelity contract tests passed'
