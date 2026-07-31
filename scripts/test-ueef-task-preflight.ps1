$ErrorActionPreference = 'Stop'
$preflight = Join-Path $PSScriptRoot 'get-ueef-task-preflight.ps1'
$ui = (& $preflight -Task 'Contradictory prose: do not design' -TaskTag ui -Scope 1 -CodeChange -Json | Out-String) | ConvertFrom-Json
if ($ui.status -ne 'READY' -or $ui.classification.route.tier -ne 'T1' -or $ui.profile.frontendMode -ne 'Quick' -or $ui.profile.skills -notcontains 'typeui-fundamentals' -or $ui.profile.skills -contains 'ui-ux-pro-max' -or $ui.profile.skills -contains 'impeccable' -or $ui.profile.workflows -notcontains 'evidence-loop') { throw 'Explicit UI preflight contract failed.' }
if ($null -eq $ui.classification.frontendRoute -or !$ui.classification.frontendRoute.applies) { throw 'Preflight must preserve the single canonical frontend-route result.' }
if ($ui.activation.mode -ne 'SOURCE_VALIDATED' -or !$ui.activation.executionAuthorized -or $ui.activation.runtimeOverall -ne 'SOURCE_VALIDATED') { throw 'Source preflight must distinguish validated source from active runtime.' }
$browser = (& $preflight -Task 'Inspect browser' -TaskTag browser -SkipHealth -Json | Out-String) | ConvertFrom-Json
if (!$browser.health.required -or $browser.health.checked) { throw 'Browser preflight must require but not probe health when explicitly skipped.' }
if ($browser.browserGate.status -ne 'REQUIRED' -or $browser.browserGate.enforcement -ne 'HARD_FAIL_BEFORE_BROWSER_TOOL') { throw 'Browser preflight must emit the mandatory hard-fail browser gate.' }
if ($browser.browserGate.allowedPath -notcontains 'Codex Chrome control plugin' -or $browser.browserGate.allowedPath -notcontains 'mcp__node_repl__js' -or $browser.browserGate.allowedPath -notcontains 'claimTab()' -or $browser.browserGate.forbiddenSurfaces -notcontains 'browser.launch') { throw 'Browser preflight gate allowlist or forbidden surfaces are incomplete.' }
if ($browser.browserGate.failureAction -notmatch 'Do not select or call a browser tool') { throw 'Browser preflight must stop tool selection before the gate is resolved.' }
$nonBrowser = (& $preflight -Task 'Document the browser policy in this repository' -SkipHealth -Json | Out-String) | ConvertFrom-Json
if ($null -ne $nonBrowser.browserGate -or $nonBrowser.profile.mcps -contains 'node_repl') { throw 'A docs task that merely mentions a browser must not require browser control.' }
$debug = (& $preflight -Task 'Fix regression' -TaskTag debugging -Scope 2 -Risk 2 -Verification 2 -RiskFloor Security -CodeChange -Json | Out-String) | ConvertFrom-Json
if ($debug.classification.route.tier -ne 'T3' -or $debug.profile.profile -ne 'ASSURED' -or $debug.profile.workflows -notcontains 'systematic-debugging' -or $debug.profile.workflows -notcontains 'independent-review') { throw 'Assured debugging preflight contract failed.' }

# A preflight owns one canonical frontend-route evaluation. Downstream profile
# and quality-gate selection must reuse that object instead of launching Node
# again. The shim counts real process invocations while preserving behavior.
$nodeCommand = (Get-Command node -ErrorAction Stop).Source
$shimRoot = Join-Path ([IO.Path]::GetTempPath()) ('ueef-node-count-' + [guid]::NewGuid().ToString('N'))
$countFile = Join-Path $shimRoot 'count.txt'
$previousPath = $env:PATH
$previousCountFile = $env:UEEF_NODE_COUNT_FILE
try {
  New-Item -ItemType Directory -Path $shimRoot -Force | Out-Null
  @"
@echo off
>>"%UEEF_NODE_COUNT_FILE%" echo 1
"$nodeCommand" %*
"@ | Set-Content -LiteralPath (Join-Path $shimRoot 'node.cmd') -Encoding ascii
  $env:UEEF_NODE_COUNT_FILE = $countFile
  $env:PATH = $shimRoot + [IO.Path]::PathSeparator + $previousPath
  $singlePass = (& $preflight -Task 'Build an Angular data grid dashboard' -SkipHealth -Json | Out-String) | ConvertFrom-Json
  $nodeInvocations = if (Test-Path -LiteralPath $countFile) { @(Get-Content -LiteralPath $countFile).Count } else { 0 }
  if ($singlePass.status -ne 'READY' -or $nodeInvocations -ne 1) { throw "Preflight must evaluate the canonical frontend route exactly once; observed $nodeInvocations Node calls." }
} finally {
  $env:PATH = $previousPath
  $env:UEEF_NODE_COUNT_FILE = $previousCountFile
  if (Test-Path -LiteralPath $shimRoot) { Remove-Item -LiteralPath $shimRoot -Recurse -Force }
}
Write-Host 'UEEF task preflight tests passed'
