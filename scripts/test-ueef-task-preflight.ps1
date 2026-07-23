$ErrorActionPreference = 'Stop'
$preflight = Join-Path $PSScriptRoot 'get-ueef-task-preflight.ps1'
$ui = (& $preflight -Task 'Contradictory prose: do not design' -TaskTag ui -Scope 1 -CodeChange -Json | Out-String) | ConvertFrom-Json
if ($ui.status -ne 'READY' -or $ui.classification.route.tier -ne 'T1' -or $ui.profile.skills -notcontains 'ui-ux-pro-max' -or $ui.profile.workflows -notcontains 'evidence-loop') { throw 'Explicit UI preflight contract failed.' }
$browser = (& $preflight -Task 'Inspect browser' -TaskTag browser -SkipHealth -Json | Out-String) | ConvertFrom-Json
if (!$browser.health.required -or $browser.health.checked) { throw 'Browser preflight must require but not probe health when explicitly skipped.' }
$debug = (& $preflight -Task 'Fix regression' -TaskTag debugging -Scope 2 -Risk 2 -Verification 2 -RiskFloor Security -CodeChange -Json | Out-String) | ConvertFrom-Json
if ($debug.classification.route.tier -ne 'T3' -or $debug.profile.profile -ne 'ASSURED' -or $debug.profile.workflows -notcontains 'systematic-debugging' -or $debug.profile.workflows -notcontains 'independent-review') { throw 'Assured debugging preflight contract failed.' }
Write-Host 'UEEF task preflight tests passed'
