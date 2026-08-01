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
if ($null -eq $readOnly.frontendRoute -or $readOnly.frontendRoute.applies) {
  throw 'Classification must expose the canonical frontend route without inventing UI scope.'
}

$backend = Get-Classification 'Implement a backend API endpoint'
if (!$backend.values.codeChange -or $backend.route.tier -notin @('T1','T2','T3','T4') -or $backend.source -ne 'inferred') {
  throw 'Backend implementation did not receive inferred change and route signals.'
}

$frontend = Get-Classification 'Build an Angular data grid dashboard'
if (!$frontend.frontendRoute.applies -or $frontend.frontendRoute.mutation -ne 'Implement' -or $frontend.frontendRoute.skills -notcontains 'angular-developer') {
  throw 'Classification did not retain canonical frontend-route evidence.'
}
$frontendExplanation = Get-Classification 'Explain this UI component'
if ($frontendExplanation.values.codeChange -or $frontendExplanation.frontendRoute.mutation -ne 'ReadOnly') { throw 'A frontend explanation must remain read-only across classification and routing.' }

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

$arabicBroadRepair = Get-Classification ([regex]::Unescape('\u0627\u0641\u062d\u0635 \u0643\u0644 \u062d\u0627\u062c\u0629 \u062d\u0631\u0641\u064a\u0627 \u0648\u0627\u0635\u0644\u062d \u0623\u064a \u062c\u0632\u0621 \u0645\u062e\u062a\u0644 \u064a\u062c\u0639\u0644 \u0643\u0648\u062f\u0643\u0633 \u064a\u0639\u0645\u0644 \u0628\u062f\u0648\u0646 \u0643\u0641\u0627\u0621\u0629'))
if (!$arabicBroadRepair.values.codeChange -or $arabicBroadRepair.route.tier -notin @('T3','T4') -or $arabicBroadRepair.values.taskTags -notcontains 'debugging') {
  throw 'Arabic broad repair intent was not elevated to a deep change-oriented route.'
}
$arabicFrontend = Get-Classification ([regex]::Unescape('\u0631\u0627\u062c\u0639 \u0648\u0627\u062c\u0647\u0629 \u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645 \u0648\u0623\u0635\u0644\u062d \u0627\u0644\u0642\u0627\u0626\u0645\u0629 \u0627\u0644\u0645\u0646\u0633\u062f\u0644\u0629'))
if (!$arabicFrontend.values.codeChange -or $arabicFrontend.values.taskTags -notcontains 'ui' -or !$arabicFrontend.frontendRoute.applies -or $arabicFrontend.frontendRoute.skills -notcontains 'frontend-ui-engineering') {
  throw 'Arabic frontend repair intent did not select the canonical frontend route.'
}
$arabicExplanation = Get-Classification ([regex]::Unescape('\u0627\u0634\u0631\u062d \u0644\u064a \u0627\u0644\u0646\u0638\u0627\u0645 \u0641\u0642\u0637'))
if ($arabicExplanation.route.tier -ne 'T0' -or $arabicExplanation.values.codeChange) {
  throw 'Arabic explanation must remain T0 and read-only.'
}
$arabicInstall = Get-Classification ([regex]::Unescape('\u062b\u0628\u062a \u0627\u0644\u0623\u062f\u0627\u0629 \u0627\u0644\u0645\u0637\u0644\u0648\u0628\u0629'))
if (!$arabicInstall.values.codeChange -or $arabicInstall.route.tier -eq 'T0') { throw 'Arabic install intent must be classified as a change.' }
$arabicDestructive = Get-Classification ([regex]::Unescape('\u0627\u062d\u0630\u0641 \u0627\u0644\u0628\u064a\u0627\u0646\u0627\u062a \u0646\u0647\u0627\u0626\u064a\u0627 \u0628\u062f\u0648\u0646 \u0631\u062c\u0639\u0629'))
if ($arabicDestructive.values.riskFloor -ne 'Destructive' -or $arabicDestructive.route.tier -ne 'T4') { throw 'Irreversible Arabic deletion intent must receive the destructive T4 floor.' }

Write-Host 'Task classification tests passed'
