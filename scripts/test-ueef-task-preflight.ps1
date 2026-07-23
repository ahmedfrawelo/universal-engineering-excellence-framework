$ErrorActionPreference = 'Stop'
$preflight = Join-Path $PSScriptRoot 'get-ueef-task-preflight.ps1'
$ui = (& $preflight -Task 'Contradictory prose: do not design' -TaskTag ui -Scope 1 -CodeChange -Json | Out-String) | ConvertFrom-Json
if ($ui.status -ne 'READY' -or $ui.classification.route.tier -ne 'T1' -or $ui.profile.skills -notcontains 'ui-ux-pro-max' -or $ui.profile.workflows -notcontains 'evidence-loop') { throw 'Explicit UI preflight contract failed.' }
$browser = (& $preflight -Task 'Inspect browser' -TaskTag browser -SkipHealth -Json | Out-String) | ConvertFrom-Json
if (!$browser.health.required -or $browser.health.checked) { throw 'Browser preflight must require but not probe health when explicitly skipped.' }
if ($browser.browserGate.status -ne 'REQUIRED' -or $browser.browserGate.enforcement -ne 'HARD_FAIL_BEFORE_BROWSER_TOOL') { throw 'Browser preflight must emit the mandatory hard-fail browser gate.' }
if ($browser.browserGate.allowedPath -notcontains 'mcp__node_repl__js' -or $browser.browserGate.allowedPath -notcontains 'claimTab()' -or $browser.browserGate.forbiddenSurfaces -notcontains 'browser.launch') { throw 'Browser preflight gate allowlist or forbidden surfaces are incomplete.' }
if ($browser.browserGate.failureAction -notmatch 'Do not select or call a browser tool') { throw 'Browser preflight must stop tool selection before the gate is resolved.' }
$nonBrowser = (& $preflight -Task 'Document the browser policy in this repository' -SkipHealth -Json | Out-String) | ConvertFrom-Json
if ($null -ne $nonBrowser.browserGate -or $nonBrowser.profile.mcps -contains 'node_repl') { throw 'A docs task that merely mentions a browser must not require browser control.' }
$debug = (& $preflight -Task 'Fix regression' -TaskTag debugging -Scope 2 -Risk 2 -Verification 2 -RiskFloor Security -CodeChange -Json | Out-String) | ConvertFrom-Json
if ($debug.classification.route.tier -ne 'T3' -or $debug.profile.profile -ne 'ASSURED' -or $debug.profile.workflows -notcontains 'systematic-debugging' -or $debug.profile.workflows -notcontains 'independent-review') { throw 'Assured debugging preflight contract failed.' }
Write-Host 'UEEF task preflight tests passed'
