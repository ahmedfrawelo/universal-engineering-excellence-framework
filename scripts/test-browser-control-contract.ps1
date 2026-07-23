$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Assert-TermsInOrder([string]$RelativePath, [string[]]$Terms) {
  $text = Get-Content -LiteralPath (Join-Path $root $RelativePath) -Raw
  $offset = -1
  foreach ($term in $Terms) {
    $next = $text.IndexOf($term, $offset + 1, [StringComparison]::Ordinal)
    if ($next -lt 0) { throw "Ordered browser recovery term '$term' missing or out of order in $RelativePath." }
    $offset = $next
  }
}

$required = @{
  'UEEF-LOADER.md' = @('user.openTabs()', 'claimTab()', 'connector-created Chrome window', 'repair-chrome-tab-ownership.ps1', 'VERIFIED_HANDOFF', 'non-visual tests can continue', 'keep visual verification explicitly pending', 'minimized, background, or non-foreground')
  'framework/01-core/01-master-loader.md' = @('user.openTabs()', 'claimTab()')
  'framework/51-browser-session-control/04-browser-and-tab-selection.md' = @('exact returned object', 'claimTab()')
  'framework/51-browser-session-control/10-window-state-preservation.md' = @('current window size', 'monitor placement', 'zoom', 'tab order', 'active tab', 'Do not call resize', 'Record the initial and final window state', 'minimized, background, or non-foreground', 'do not pause or block the goal')
  'framework/51-browser-session-control/11-control-surface-selection.md' = @('Chrome plugin extension binding', 'mcp__node_repl__js', 'mcp__playwright__*', 'tab.playwright', 'visible Windows control only when')
  'framework/51-browser-session-control/09-platform-authorized-chrome-control.md' = @('bootstrap-troubleshooting', 'chrome-troubleshooting', 'Do not invent a `file:///` variant', 'keep the task active')
  'framework/51-browser-session-control/12-cross-session-evidence-handoff.md' = @('THREAD_CONTROL_CHANNEL_DEGRADED', 'CHROME_EXTERNALLY_UNAVAILABLE', 'VERIFIED_HANDOFF', 'trusted coordinator', 'existing user-owned tab', 'current code state')
  'framework/51-browser-session-control/13-user-facing-recovery-protocol.md' = @('first local bridge failure', 'Do not expose attempt counts', 'Browser verification is being completed on your existing tab; implementation continues.')
  'framework/51-browser-session-control/14-automatic-tab-ownership-recovery.md' = @('already part of another browser session', 'Do not ask the user to Share, Connect, restart Chrome, open another tab, or wait for another task', 'repair-chrome-tab-ownership.ps1', 'user.openTabs()', 'exact returned target object', 'claimTab()', 'one automated recovery', 'without a coordinator or user action')
  'framework/51-browser-session-control/15-chrome-control-readiness.md' = @('Chrome readiness flow', 'browser-client.mjs', 'not a connector-created browser', 'user.openTabs()', 'claimTab()', 'repair-chrome-tab-ownership.ps1', 'same extension binding', 'VERIFIED_HANDOFF', 'same tab and current code state', 'continue non-browser work', 'chrome.tabs.finalize(...)', 'not enough to prove that Chrome cannot be used')
  'framework/51-browser-session-control/16-control-channel-failover.md' = @('same user-owned tab', 'Automatic Failover', 'VERIFIED_HANDOFF', 'visible Windows control', 'never creates')
  'framework/51-browser-session-control/07-browser-task-verification.md' = @('do not report `COMPLETE`', 'structural equivalence', 'same-tab evidence', 'chrome.tabs.finalize(...)', 'prevents stale cross-task ownership')
  'framework/27-quality-gates/23-browser-session-control-gate.md' = @('user.openTabs()', 'claimTab()', 'Chrome readiness flow', 'Do not fail because')
  'framework/03-runtime/00-runtime-sequence.md' = @('Chrome readiness flow completed:', 'Exact user.openTabs() object claimed:', 'Automatic ownership repair run when needed:', 'Banner classification:', 'PARTIAL_VISUAL_GATE')
  'framework/29-checklists/32-browser-session-control-checklist.md' = @('exact returned object', 'Debugging/CDP authorization')
  'scripts/sync-runtime.ps1' = @('user.openTabs()', 'claimTab()', 'Chrome readiness flow', 'Extension attachment', 'must not pause the goal', 'THREAD_CONTROL_CHANNEL_DEGRADED', 'VERIFIED_HANDOFF', 'Do not expose retry counts', 'repair-chrome-tab-ownership.ps1')
  'scripts/repair-chrome-tab-ownership.ps1' = @('extension-host.exe', 'chrome-extension://hehggadaopoacecdllhhajmbjkdcmajg/', 'Stop-Process', 'DryRun')
}
foreach ($relative in $required.Keys) {
  $text = Get-Content -LiteralPath (Join-Path $root $relative) -Raw
  foreach ($term in $required[$relative]) {
    if ($text -notmatch [regex]::Escape($term)) { throw "Browser contract term '$term' missing from $relative." }
  }
}

$policyText = Get-Content -LiteralPath (Join-Path $root 'framework/51-browser-session-control/11-control-surface-selection.md') -Raw
if ($policyText -match 'prefer verified visible Windows control') { throw 'Obsolete Windows-first Chrome policy remains.' }
if ($policyText -notmatch 'Do not use directly exposed') { throw 'Direct external browser MCP prohibition is missing.' }
$generatedText = Get-Content -LiteralPath (Join-Path $root 'scripts/sync-runtime.ps1') -Raw
if ($generatedText -match 'Automation banners, Codex-titled browser windows, and unverified profiles are BLOCKED') { throw 'Obsolete banner-only browser block remains.' }
$forbiddenBrowserTerms = @('Active window identity verified:', 'Automation banner visible: NO / BLOCKED', 'currently visible browser window')
foreach ($term in $forbiddenBrowserTerms) {
  if ((Get-ChildItem -LiteralPath (Join-Path $root 'framework') -Recurse -File -Filter *.md | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -match [regex]::Escape($term)) { throw "Obsolete browser contract term remains: $term" }
}
$masterText = Get-Content -LiteralPath (Join-Path $root 'framework/01-core/01-master-loader.md') -Raw
if ($masterText -notmatch 'Load modules `00` through `16`') { throw 'Required browser modules are not selected.' }
$isolatedText = Get-Content -LiteralPath (Join-Path $root 'framework/51-browser-session-control/03-no-isolated-browser-by-default.md') -Raw
if ($isolatedText -match 'Isolated contexts are acceptable') { throw 'Isolated Chrome fallback remains.' }
$checklistText = Get-Content -LiteralPath (Join-Path $root 'framework/29-checklists/32-browser-session-control-checklist.md') -Raw
if ($checklistText -match 'Explicit consent recorded if an isolated fallback was necessary') { throw 'Consent-based isolated fallback remains.' }
$handoffText = Get-Content -LiteralPath (Join-Path $root 'framework/51-browser-session-control/12-cross-session-evidence-handoff.md') -Raw
if ($handoffText -notmatch 'Do not mark the task `BLOCKED`') { throw 'Cross-session evidence handoff does not prohibit false blocking.' }
$browserContractText = Get-ChildItem -LiteralPath (Join-Path $root 'framework/51-browser-session-control') -File -Filter *.md | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }
foreach ($term in @('wait for the user to say', 'ask the user to say', 'say `تم`', 'say ''تم''', 'say "تم"')) {
  if ($browserContractText -match [regex]::Escape($term)) { throw "Manual user-confirmation browser handoff remains: $term" }
}
Assert-TermsInOrder 'framework/51-browser-session-control/15-chrome-control-readiness.md' @(
  'browser-client.mjs',
  'claimTab()',
  'repair-chrome-tab-ownership.ps1',
  'VERIFIED_HANDOFF'
)
$readinessText = Get-Content -LiteralPath (Join-Path $root 'framework/51-browser-session-control/15-chrome-control-readiness.md') -Raw
foreach ($term in @('A platform permission prompt is normal authorization', 'Only report `CHROME_EXTERNALLY_UNAVAILABLE`', 'not enough to prove that Chrome cannot be used', 'cannot become a false `BLOCKED` state')) {
  if ($readinessText -notmatch [regex]::Escape($term)) { throw "Chrome readiness contract missing root-cause guard: $term" }
}
$failoverText = Get-Content -LiteralPath (Join-Path $root 'framework/51-browser-session-control/16-control-channel-failover.md') -Raw
if ($failoverText -notmatch 'No user acknowledgement') { throw 'Control-channel failover still permits a manual acknowledgement.' }

$strictBrowserFiles = @('UEEF-LOADER.md','scripts/sync-runtime.ps1','framework/51-browser-session-control/00-browser-session-first.md','framework/51-browser-session-control/11-control-surface-selection.md')
foreach ($relative in $strictBrowserFiles) {
  $text = Get-Content -LiteralPath (Join-Path $root $relative) -Raw
  foreach ($term in @('Cursor/IDE Simple Browser','browser.newContext','browser.launch','explicit separate user request')) {
    if ($text -notmatch [regex]::Escape($term)) { throw "Alternate-browser prohibition '$term' missing from $relative." }
  }
  if ($text -match 'They remain valid for authorized isolated/local testing') { throw "Broad isolated-browser fallback remains in $relative." }
}
$loaderText = Get-Content -LiteralPath (Join-Path $root 'UEEF-LOADER.md') -Raw
if ($loaderText -notmatch 'explicit separate user request' -or $loaderText -notmatch 'never substitutes for a user-owned Chrome task' -or $loaderText -notmatch 'stop and request the user to activate or share the existing tab') { throw 'Loader does not constrain isolated tests and hard stop.' }
foreach ($relative in @('UEEF-LOADER.md','scripts/sync-runtime.ps1','framework/51-browser-session-control/00-browser-session-first.md')) {
  $text = Get-Content -LiteralPath (Join-Path $root $relative) -Raw
  foreach ($term in @('HARD FAIL BEFORE ANY BROWSER TOOL','get-ueef-task-preflight.ps1','browserGate','do not select a browser tool','mcp__node_repl__js','claimTab()','tab.playwright')) {
    if ($text -notmatch [regex]::Escape($term)) { throw "Mandatory pre-tool browser gate term '$term' missing from $relative." }
  }
}
$preflightText = Get-Content -LiteralPath (Join-Path $root 'scripts/get-ueef-task-preflight.ps1') -Raw
foreach ($term in @("status = 'REQUIRED'", "enforcement = 'HARD_FAIL_BEFORE_BROWSER_TOOL'", 'requiredBeforeTool', 'allowedPath', 'forbiddenSurfaces', 'Do not select or call a browser tool')) {
  if ($preflightText -notmatch [regex]::Escape($term)) { throw "Structured browser preflight gate term '$term' missing." }
}

$previousCodexHome = $env:CODEX_HOME
try {
  if (!$env:CODEX_HOME) { $env:CODEX_HOME = 'E:\shared folder\codex-home' }
  $bootstrapOutput = (& (Join-Path $root 'scripts/environment-bootstrap.ps1') 2>&1 | Out-String)
  if ($bootstrapOutput -match 'Collection was of a fixed size') { throw 'Default environment bootstrap still uses a fixed-size collection.' }
} finally {
  $env:CODEX_HOME = $previousCodexHome
}

Write-Host 'Browser control contract tests passed'
