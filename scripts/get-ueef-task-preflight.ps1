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
$route = (& (Join-Path $PSScriptRoot 'select-agent-route.ps1') -Scope $Scope -Ambiguity $Ambiguity -Coupling $Coupling -Risk $Risk -Verification $Verification -RiskFloor $RiskFloor -CodeChange:$CodeChange -Json | Out-String) | ConvertFrom-Json
$profile = (& (Join-Path $PSScriptRoot 'select-capability-profile.ps1') -Task $Task -TaskTag $TaskTag -RouteTier $route.tier -RiskFloor $RiskFloor -CodeChange:$CodeChange -Json | Out-String) | ConvertFrom-Json
$healthRequired = $IncludeHealth.IsPresent -or $profile.capabilityHealthRequired
$health = $null
if ($healthRequired -and !$SkipHealth) {
  $raw = & (Join-Path $PSScriptRoot 'get-ueef-health.ps1') -Json 2>$null | Out-String
  if ($raw) { $health = $raw | ConvertFrom-Json }
}
$status = if ($health -and $health.runtime.overall -ne 'ACTIVE') { 'BLOCKED' } elseif ($healthRequired -and !$health) { 'READY_WITH_FALLBACK' } else { 'READY' }
$browserGate = $null
if ($TaskTag -contains 'browser') {
  $browserGate = [ordered]@{
    status = 'REQUIRED'
    enforcement = 'HARD_FAIL_BEFORE_BROWSER_TOOL'
    requiredBeforeTool = @(
      'Read the installed Chrome control skill.',
      'Bootstrap browser-client.mjs only through mcp__node_repl__js.',
      'Select the Chrome extension binding.',
      'Enumerate user.openTabs() and pass the exact returned object to claimTab().',
      'Use tab.playwright only after the exact user-owned tab is claimed.'
    )
    allowedPath = @('mcp__node_repl__js', 'Chrome extension binding', 'user.openTabs()', 'claimTab()', 'claimed tab.playwright')
    forbiddenSurfaces = @('mcp__playwright__*', 'mcp__chrome_devtools__*', 'browser_*', 'Cursor/IDE Simple Browser', 'in-app browser', 'browser.newContext', 'browser.launch', 'second browser', 'temporary profile', 'isolated context')
    failureAction = 'Do not select or call a browser tool and do not open an alternate surface. Run the Chrome readiness and same-tab recovery flow.'
  }
}
$result = [ordered]@{ schemaVersion=2; generatedAt=(Get-Date).ToUniversalTime().ToString('o'); status=$status; task=$Task; classification=[ordered]@{source='explicit';tags=@($TaskTag);route=$route}; profile=$profile; health=[ordered]@{required=$healthRequired;checked=[bool]$health;status=if($health){$health.overall.status}else{'SKIPPED'};report=$health}; browserGate=$browserGate; decisions=@($profile.workflowDecisions) }
if ($Json) { $result | ConvertTo-Json -Depth 10 } else { Write-Output "UEEF task preflight: $status"; Write-Output "Route: $($route.tier)"; Write-Output "Profile: $($profile.profile)"; Write-Output "Health: $($result.health.status)" }
if ($status -eq 'BLOCKED') { exit 1 }
