[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Task,
  [ValidateRange(0,3)][int]$Scope = 0,
  [ValidateRange(0,3)][int]$Ambiguity = 0,
  [ValidateRange(0,3)][int]$Coupling = 0,
  [ValidateRange(0,3)][int]$Risk = 0,
  [ValidateRange(0,3)][int]$Verification = 0,
  [ValidateSet('None','Architecture','Authentication','Authorization','Security','Production','Migration','Destructive','Privacy','Payment','Incident','Release')][string]$RiskFloor = 'None',
  [ValidateSet('ui','browser','current-docs','ambiguous','debugging')][string[]]$TaskTag = @(),
  [switch]$CodeChange,
  [switch]$IncludeHealth,
  [switch]$SkipHealth,
  [switch]$Json
)
$ErrorActionPreference = 'Stop'
$inputParameters = @{} + $PSBoundParameters
$classificationArgs = @{ Task=$Task; Json=$true }
foreach ($name in @('Scope','Ambiguity','Coupling','Risk','Verification','RiskFloor','TaskTag','CodeChange')) {
  if ($inputParameters.ContainsKey($name)) { $classificationArgs[$name] = $inputParameters[$name] }
}
$classification = (& (Join-Path $PSScriptRoot 'get-ueef-task-classification.ps1') @classificationArgs | Out-String) | ConvertFrom-Json
$route = $classification.route
$profile = (& (Join-Path $PSScriptRoot 'select-capability-profile.ps1') -Task $Task -TaskTag $classification.values.taskTags -RouteTier $route.tier -RiskFloor $classification.values.riskFloor -CodeChange:([bool]$classification.values.codeChange) -ClassificationSource $classification.source -FrontendRoute $classification.frontendRoute -Json | Out-String) | ConvertFrom-Json

$repositoryPath = Split-Path -Parent $PSScriptRoot
$runtimeStatus = (& (Join-Path $PSScriptRoot 'ueef-status.ps1') -RepositoryPath $repositoryPath -SkipRuntimeDrift -Json | Out-String) | ConvertFrom-Json
$activationMode = if ($runtimeStatus.mode -eq 'managed-runtime' -and $runtimeStatus.overall -eq 'ACTIVE') {
  'ACTIVE_RUNTIME'
} elseif ($runtimeStatus.mode -eq 'source-checkout' -and $runtimeStatus.overall -eq 'SOURCE_VALIDATED') {
  'SOURCE_VALIDATED'
} else {
  'INACTIVE'
}
$executionAuthorized = $activationMode -in @('ACTIVE_RUNTIME','SOURCE_VALIDATED')

$healthRequired = $IncludeHealth.IsPresent -or $profile.capabilityHealthRequired
$health = $null
if ($healthRequired -and !$SkipHealth) {
  $raw = & (Join-Path $PSScriptRoot 'get-ueef-health.ps1') -RepositoryPath $repositoryPath -Json 2>$null | Out-String
  if ($raw) { $health = $raw | ConvertFrom-Json }
}
$status = if (!$executionAuthorized) {
  'BLOCKED'
} elseif ($health -and $health.overall.status -eq 'FAIL') {
  'BLOCKED'
} elseif ($healthRequired -and !$health) {
  'READY_WITH_FALLBACK'
} else {
  'READY'
}
$browserGate = $null
if ($classification.values.taskTags -contains 'browser') {
  $browserGate = [ordered]@{
    status = 'REQUIRED'
    enforcement = 'HARD_FAIL_BEFORE_BROWSER_TOOL'
    requiredBeforeTool = @(
      'Read the installed Chrome control skill for the current host.',
      'Prefer the Codex Chrome control plugin against the user existing tabs/profile when available.',
      'On Claude hosts, bootstrap browser-client.mjs only through mcp__node_repl__js, then use the Chrome extension binding.',
      'Enumerate user.openTabs() and pass the exact returned object to claimTab() when that bridge is present.',
      'Never launch Playwright MCP, IDE Simple Browser, in-app browser, browser.newContext, or browser.launch as a substitute.',
      'Treat Chrome DevTools/CDP as AUTHORIZED_LOOPBACK_LAST_RESORT only after every configured prior stage failed, explicit user authorization, and READY_LAST_RESORT from the readiness probe; stricter host rules win.'
    )
    allowedPath = @('Codex Chrome control plugin', 'mcp__node_repl__js', 'Chrome extension binding', 'user.openTabs()', 'claimTab()', 'claimed tab.playwright', 'authorized loopback CDP on the same existing target')
    forbiddenSurfaces = @('mcp__playwright__*', 'mcp__chrome_devtools__* outside AUTHORIZED_LOOPBACK_LAST_RESORT', 'browser_*', 'Cursor/IDE Simple Browser', 'in-app browser', 'browser.newContext', 'browser.launch', 'second browser', 'temporary profile', 'isolated context', 'non-loopback CDP', 'cookie/storage/profile inspection')
    emergencyFallback = [ordered]@{status='EXPLICIT_LAST_RESORT_ONLY';policy='config/browser-emergency-fallback.json';probe='scripts/get-remote-debugging-readiness.ps1 -AuthorizedLastResort -PriorStageFailure <recorded-stages>';requiredResult='READY_LAST_RESORT';incompleteResult='PRIOR_STAGES_INCOMPLETE';requiresUserAuthorization=$true;requiresAllPriorStageEvidence=$true;hostRulesWin=$true}
    failureAction = 'Do not select or call a browser tool outside allowedPath and do not invent another surface. After every authorized path and eligible explicit emergency fallback is unavailable, stop and report the exact missing condition.'
  }
}
$result = [ordered]@{
  schemaVersion = 3
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  status = $status
  task = $Task
  classification = $classification
  activation = [ordered]@{
    mode = $activationMode
    executionAuthorized = $executionAuthorized
    runtimeMode = $runtimeStatus.mode
    runtimeOverall = $runtimeStatus.overall
    status = $runtimeStatus
  }
  profile = $profile
  health = [ordered]@{
    required = $healthRequired
    checked = [bool]$health
    status = if($health){$health.overall.status}else{'SKIPPED'}
    report = $health
  }
  browserGate = $browserGate
  decisions = @($profile.workflowDecisions)
}
if ($Json) { $result | ConvertTo-Json -Depth 10 } else { Write-Output "UEEF task preflight: $status"; Write-Output "Route: $($route.tier)"; Write-Output "Profile: $($profile.profile)"; Write-Output "Health: $($result.health.status)" }
if ($status -eq 'BLOCKED') { exit 1 }
