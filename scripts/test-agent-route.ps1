$ErrorActionPreference = 'Stop'
$selector = Join-Path $PSScriptRoot 'select-agent-route.ps1'
$catalog = Join-Path $PSScriptRoot 'fixtures\model-catalog.json'

function Assert-Route {
  param([hashtable]$Arguments, [hashtable]$Expected)
  if (!$Arguments.ContainsKey('ModelCatalogPath')) { $Arguments.ModelCatalogPath = $catalog }
  $Arguments.TestModelCatalog = $true
  $actual = (& $selector @Arguments -Json | ConvertFrom-Json)
  foreach ($key in $Expected.Keys) {
    if ($actual.$key -ne $Expected[$key]) {
      throw "Route assertion failed for $key. Expected '$($Expected[$key])', got '$($actual.$key)'."
    }
  }
}

Assert-Route @{} @{ schemaVersion=4; tier='T0'; reasoning='low'; displayReasoning='low'; hostReasoning='low'; preferredModel='gpt-5.3-codex-spark'; modelSelectionMode='TEST_ONLY_ROUTE'; fallbackModel='gpt-5.6-luna'; reasoningCeiling='high'; topology='single-agent'; spawnAgents=$false; catalogModelCount=8; generalModelCount=7 }
Assert-Route @{ CodeChange=$true } @{ tier='T1'; preferredModel='gpt-5.6-luna'; reasoning='low'; modelSelectionMode='TEST_ONLY_ROUTE'; codeChange=$true; spawnAgents=$false; noSpawnReason='NO_INDEPENDENT_WORK'; routeEvidenceRequired=$true; invocationIndex=0; effortRotation='INVOCATION_CYCLE' }
Assert-Route @{ Scope=2; Ambiguity=2; Coupling=1; Risk=1; Verification=1 } @{ tier='T2'; preferredModel='gpt-5.4'; reasoning='low'; modelSelectionMode='TEST_ONLY_ROUTE'; topology='single-agent'; spawnAgents=$false }
Assert-Route @{ Scope=2; Ambiguity=2; Coupling=1; Risk=1; Verification=1; DelegationBenefit=$true } @{ tier='T2'; topology='lead-plus-sidecar'; spawnAgents=$true }
Assert-Route @{ RiskFloor='Authentication' } @{ tier='T3'; preferredModel='gpt-5.6-sol'; reasoning='low'; fallbackModel='gpt-5.5'; fallbackReasoning='low'; freshReviewMode='FRESH_CONTEXT_RECOMMENDED'; freshReviewRequired=$false }
Assert-Route @{ RiskFloor='Privacy' } @{ tier='T4'; preferredModel='gpt-5.6-sol'; reasoning='medium'; fallbackModel='gpt-5.5'; reasoningCeiling='high'; independentVerificationRequired=$true; freshReviewMode='FRESH_CONTEXT_REQUIRED'; freshReviewRequired=$true }
Assert-Route @{ RiskFloor='Payment'; DelegationBenefit=$true } @{ tier='T4'; topology='lead-plus-independent-verifier'; spawnAgents=$true }
Assert-Route @{ RiskFloor='Payment'; DelegationBenefit=$true; IndependentWorkstreams=2 } @{ tier='T4'; topology='lead-workers-independent-verifier'; spawnAgents=$true }
Assert-Route @{ Scope=3; Ambiguity=3; Coupling=3; Risk=2; Verification=1; DelegationBenefit=$true; IndependentWorkstreams=1 } @{ tier='T3'; topology='lead-plus-sidecar' }
Assert-Route @{ Scope=3; Ambiguity=3; Coupling=3; Risk=2; Verification=1; DelegationBenefit=$true; IndependentWorkstreams=2 } @{ tier='T3'; topology='parallel-specialists' }
Assert-Route @{ Scope=2; Ambiguity=2; Coupling=1; Risk=1; Verification=1; DelegationBenefit=$true; AgentsUnavailable=$true } @{ topology='single-agent'; spawnAgents=$false; agentsAvailable=$false }
Assert-Route @{ CodeChange=$true; AgentsUnavailable=$true } @{ tier='T1'; spawnAgents=$false; agentsAvailable=$false; noSpawnReason='TOOL_UNAVAILABLE'; routeEvidenceRequired=$true }
Assert-Route @{ RiskFloor='Authentication'; ModelsUnavailable=$true } @{ preferredModel=$null; modelAvailabilityMustBeVerified=$false }
Assert-Route @{ Scope=2; Ambiguity=2; Coupling=1; Risk=1; Verification=1; UseCurrentModel=$true; CurrentModel='gpt-5.6-luna' } @{ preferredModel='gpt-5.6-luna'; reasoning='low'; currentModelConstraintApplied=$true; currentModelConstraintOverridden=$false }
Assert-Route @{ Scope=2; Ambiguity=2; Coupling=1; Risk=1; Verification=1; InvocationIndex=1 } @{ tier='T2'; reasoning='medium'; invocationIndex=1; effortRotation='INVOCATION_CYCLE' }
Assert-Route @{ Scope=2; Ambiguity=2; Coupling=1; Risk=1; Verification=1; InvocationIndex=2 } @{ tier='T2'; reasoning='high'; invocationIndex=2; effortRotation='INVOCATION_CYCLE' }
Assert-Route @{ RiskFloor='Privacy'; UseCurrentModel=$true; CurrentModel='gpt-5.6-luna'; ReasoningOverride='xhigh'; AllowExceed=$true; AllowModelConstraintOverride=$true } @{ preferredModel='gpt-5.6-sol'; reasoning='xhigh'; aboveCeilingAuthorized=$true; currentModelConstraintOverridden=$true }

$criticalRejected = $false
try { & $selector -Risk 3 -Json | Out-Null } catch { $criticalRejected = $true }
if (!$criticalRejected) { throw 'Risk 3 without RiskFloor must be rejected.' }

$root = Split-Path -Parent $PSScriptRoot
$contractChecks = @{
  'UEEF-LOADER.md' = @('Agent route:', 'NO_INDEPENDENT_WORK')
  'framework/58-agent-model-orchestration/00-agent-model-orchestration-system.md' = @('Visible pre-command route line', 'TOOL_UNAVAILABLE', 'fresh-context review')
  'framework/58-agent-model-orchestration/06-fresh-context-review-protocol.md' = @('FRESH_CONTEXT_REQUIRED', 'reviewed diff SHA-256', 'validate-fresh-review-evidence.ps1')
  'framework/27-quality-gates/31-agent-model-routing-gate.md' = @('TOOL_UNAVAILABLE', 'child-agent record')
  'framework/29-checklists/40-agent-model-routing-checklist.md' = @('Visible pre-command route line', 'Child agent identity', 'TOOL_UNAVAILABLE')
  'framework/38-templates/28-agent-routing-decision-template.md' = @('Visible pre-command route line', 'Child agent identity', 'TOOL_UNAVAILABLE')
  'scripts/sync-runtime.ps1' = @('Agent route:', 'TOOL_UNAVAILABLE')
}
foreach ($relativePath in $contractChecks.Keys) {
  $content = Get-Content -LiteralPath (Join-Path $root $relativePath) -Raw
  foreach ($term in $contractChecks[$relativePath]) {
    if ($content -notmatch [regex]::Escape($term)) { throw "Agent contract term '$term' missing from $relativePath." }
  }
}
$topologyText = Get-Content -LiteralPath (Join-Path $root 'framework/58-agent-model-orchestration/03-agent-topologies.md') -Raw
if ($topologyText -notmatch 'T1 defaults to single-agent') { throw 'Topology policy does not preserve the single-agent T1 default.' }
$freshReviewText = Get-Content -LiteralPath (Join-Path $root 'framework\58-agent-model-orchestration\06-fresh-context-review-protocol.md') -Raw
if ($freshReviewText -notmatch 'T4' -or $freshReviewText -notmatch 'fresh-context') { throw 'Fresh review protocol is incomplete.' }

foreach ($routeArgs in @(@{}, @{Scope=1;Ambiguity=1;Coupling=1;Risk=1;Verification=1}, @{RiskFloor='Authentication'}, @{RiskFloor='Privacy'})) {
  $routeArgs.ModelCatalogPath = $catalog
  $routeArgs.TestModelCatalog = $true
  $route = & $selector @routeArgs -Json | ConvertFrom-Json
  if ($route.reasoning -notin @('low','medium','high')) { throw "Ordinary route exceeded the low/medium/high ceiling: $($route.reasoning)" }
}

$bashPath = if (Test-Path 'C:\Program Files\Git\bin\bash.exe') { 'C:\Program Files\Git\bin\bash.exe' } else { '' }
if ($bashPath) {
  $psRoute = & $selector -RiskFloor Payment -DelegationBenefit -IndependentWorkstreams 2 -ModelCatalogPath $catalog -TestModelCatalog -Json | ConvertFrom-Json
  $shSelector = (Join-Path $PSScriptRoot 'select-agent-route.sh').Replace('\','/')
  $shRoute = & $bashPath $shSelector --risk-floor Payment --delegation-benefit --independent-workstreams 2 --model-catalog $catalog --test-model-catalog | ConvertFrom-Json
  $psProperties = @($psRoute.psobject.Properties.Name | Sort-Object)
  $shProperties = @($shRoute.psobject.Properties.Name | Sort-Object)
  if (($psProperties -join '|') -ne ($shProperties -join '|')) { throw 'PowerShell and Unix route schemas differ.' }
  foreach ($property in $psProperties) {
    if ([string]$psRoute.$property -ne [string]$shRoute.$property) { throw "PowerShell and Unix route values differ for $property." }
  }
}

$capabilityRouting = Get-Content -LiteralPath (Join-Path $root 'framework\58-agent-model-orchestration\02-model-capability-routing.md') -Raw
if ($capabilityRouting -notmatch 'economical default, not a hard ceiling') {
  throw 'Model capability routing does not document proportional reasoning.'
}
foreach($term in @('Model used: UNVERIFIED','picker label','screenshot','assistant self-report','do not claim completion')) {
  if ($capabilityRouting -notmatch [regex]::Escape($term)) { throw "Model anti-hallucination routing term missing: $term" }
}

$integrationRoot = Join-Path ([IO.Path]::GetTempPath()) ('ueef-route-integration-' + [guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory -Path $integrationRoot -Force | Out-Null
  $liveCatalogPath = Join-Path $integrationRoot 'live-catalog.json'
  $fixture = Get-Content -LiteralPath $catalog -Raw | ConvertFrom-Json
  $liveCatalog = [ordered]@{schemaVersion=1;discoveredAt=(Get-Date).ToUniversalTime().ToString('o');provenance=[ordered]@{provider='test-fixture'};data=@($fixture.data)}
  [IO.File]::WriteAllText($liveCatalogPath, ($liveCatalog | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
  $liveRoutePath = Join-Path $integrationRoot 'route.json'
  $liveRoute = & $selector -RiskFloor Privacy -ModelCatalogPath $liveCatalogPath -TestModelCatalog -Json | ConvertFrom-Json
  if (!$liveRoute.testCatalogAllowed -or !$liveRoute.catalogProvider -or !$liveRoute.catalogDiscoveredAt) { throw 'Public selector dropped required test-catalog provenance.' }
  [IO.File]::WriteAllText($liveRoutePath, ($liveRoute | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
  $dispatchPath = Join-Path $integrationRoot 'dispatch.json'
  $completionPath = Join-Path $integrationRoot 'completion.json'
  $receiptPath = Join-Path $integrationRoot 'receipt.json'
  [IO.File]::WriteAllText($dispatchPath, (@{threadId='selector-thread';hostId='local'} | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText($completionPath, (@{provider='codex-app:read-thread';threadId='selector-thread';turnId='selector-turn';observedAt=(Get-Date).ToUniversalTime().ToString('o');actualModel=$liveRoute.preferredModel;actualHostReasoning=$liveRoute.hostReasoning;result='SUCCESS'} | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
  & node (Join-Path $PSScriptRoot 'record-model-route-result.mjs') --allow-test-route --route $liveRoutePath --dispatch-result $dispatchPath --completion-result $completionPath --output $receiptPath | Out-Null
  if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $receiptPath)) { throw 'Public selector output could not produce a model execution receipt.' }
} finally {
  if (Test-Path -LiteralPath $integrationRoot) { Remove-Item -LiteralPath $integrationRoot -Recurse -Force }
}
& node (Join-Path $PSScriptRoot 'test-model-routing-policy.mjs') | Out-Null

Write-Host 'Agent route tests passed'
