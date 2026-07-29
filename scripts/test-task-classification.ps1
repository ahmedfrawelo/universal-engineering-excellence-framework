[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$selector = Join-Path $PSScriptRoot 'get-ueef-task-classification.ps1'

function Get-Classification([string]$Task, [hashtable]$Overrides = @{}) {
  $args = @{ Task=$Task; Json=$true }
  foreach ($key in $Overrides.Keys) { $args[$key] = $Overrides[$key] }
  return (& $selector @args | Out-String) | ConvertFrom-Json
}

$readOnly = Get-Classification 'Explain dependency injection'
if ($readOnly.route.tier -ne 'T0' -or $readOnly.values.codeChange) {
  throw 'A self-contained explanation must be inferred as T0 and read-only.'
}

$backend = Get-Classification 'Implement a backend API endpoint'
if (!$backend.values.codeChange -or $backend.route.tier -notin @('T1','T2','T3','T4') -or $backend.source -ne 'inferred') {
  throw 'Backend implementation did not receive inferred change and route signals.'
}

$browser = Get-Classification 'Inspect the existing Chrome tab visually'
if ($browser.values.taskTags -notcontains 'browser' -or $browser.values.codeChange) {
  throw 'Browser inspection did not infer the browser tag without inventing a code change.'
}

$explicit = Get-Classification 'Contradictory prose: do not design' @{ TaskTag=@('ui'); Scope=1; CodeChange=$true }
if ($explicit.source -ne 'mixed' -or $explicit.values.taskTags -notcontains 'ui' -or $explicit.values.taskTags -notcontains 'ambiguous' -or $explicit.route.tier -ne 'T1') {
  throw 'Explicit and inferred classification signals were not merged explainably.'
}

$critical = Get-Classification 'Perform a production payment migration'
if ($critical.route.tier -ne 'T4' -or $critical.values.riskFloor -notin @('Production','Payment','Migration')) {
  throw 'Critical production migration was not elevated to T4 with a risk floor.'
}

Write-Host 'Task classification tests passed'
