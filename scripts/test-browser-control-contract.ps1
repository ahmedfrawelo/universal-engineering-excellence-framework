$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$arabicDone = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('2KrZhQ=='))

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
  'UEEF-LOADER.md' = @('Chrome family explicitly', 'dedicated task tab', 'user.openTabs()', 'working tab unless explicitly requested', 'in-app browser', 'stage', 'reason', 'AUTHORIZED_LOOPBACK_LAST_RESORT', 'repair-chrome-tab-ownership.ps1', 'Host or installed-skill prohibitions still win', 'open Chrome first, then restart Codex', 'non-visual tests can continue', 'minimized, background, or non-foreground')
  'framework/01-core/01-master-loader.md' = @('user.openTabs()', 'claimTab()')
  'framework/51-browser-session-control/04-browser-and-tab-selection.md' = @('user.openTabs()', 'dedicated task tab', 'same existing window/profile/session', 'explicitly asks to use that tab', 'claimTab()')
  'framework/51-browser-session-control/10-window-state-preservation.md' = @('current window size', 'monitor placement', 'zoom', 'tab order', 'active tab', 'Do not call resize', 'Record the initial and final window state', 'minimized, background, or non-foreground', 'do not pause or block the goal')
  'framework/51-browser-session-control/11-control-surface-selection.md' = @('explicit Chrome-family binding', 'agent.browsers.get("chrome")', 'dedicated task tab', 'getDefault()', 'getForUrl()', 'get("iab")', 'mcp__playwright__*', 'tab.playwright', 'AUTHORIZED_LOOPBACK_LAST_RESORT', 'ExpectedTargetId', 'READY_LAST_RESORT', 'sameTargetProven', 'loopback-only', 'A stricter system, host, plugin, or installed-skill rule overrides', 'visible Windows control only on Windows', 'macOS/Linux')
  'framework/51-browser-session-control/09-platform-authorized-chrome-control.md' = @('bootstrap-troubleshooting', 'chrome-troubleshooting', 'Do not invent a `file:///` variant', 'keep the task active')
  'framework/51-browser-session-control/12-cross-session-evidence-handoff.md' = @('THREAD_CONTROL_CHANNEL_DEGRADED', 'CHROME_EXTERNALLY_UNAVAILABLE', 'VERIFIED_HANDOFF', 'trusted coordinator', 'dedicated task tab', 'same-target', 'current code state')
  'framework/51-browser-session-control/13-user-facing-recovery-protocol.md' = @('first local bridge failure', 'open Chrome first and then restart Codex', 'stage', 'reason', 'next', 'generic connection/channel failure', 'AUTHORIZED_LOOPBACK_LAST_RESORT', 'in-app browser')
  'framework/51-browser-session-control/14-automatic-tab-ownership-recovery.md' = @('dedicated task tab', 'browser-control session', 'Do not ask the user to Share, Connect, restart Chrome, open another tab, or wait for another task', 'repair-chrome-tab-ownership.ps1', 'user.openTabs()', 'exact returned target object', 'claimTab()', 'one automated recovery', 'without a coordinator or user action')
  'framework/51-browser-session-control/15-chrome-control-readiness.md' = @('Chrome readiness flow', 'browser-client.mjs', 'agent.browsers.get("chrome")', 'getDefault()', 'user.openTabs()', 'dedicated task tab', 'working tab by default', 'claimTab()', 'repair-chrome-tab-ownership.ps1', 'stage/reason/next', 'VERIFIED_HANDOFF', 'AUTHORIZED_LOOPBACK_LAST_RESORT', 'ExpectedTargetId', 'READY_LAST_RESORT', 'sameTargetProven', 'open Chrome first, then restart Codex', 'current code state', 'chrome.tabs.finalize(...)', 'not enough to prove that Chrome cannot be used')
  'framework/51-browser-session-control/16-control-channel-failover.md' = @('Same-Target', 'dedicated task tab', 'Automatic Failover', 'VERIFIED_HANDOFF', 'visible Windows control', 'AUTHORIZED_LOOPBACK_LAST_RESORT', 'ExpectedTargetId', 'READY_LAST_RESORT', 'sameTargetProven', 'in-app browser', 'stage and cause category', 'macOS/Linux')
  'framework/51-browser-session-control/07-browser-task-verification.md' = @('do not report `COMPLETE`', 'structural equivalence', 'same-target evidence', 'dedicated task tab', 'chrome.tabs.finalize(...)', 'prevents stale cross-task ownership')
  'framework/27-quality-gates/23-browser-session-control-gate.md' = @('user.openTabs()', 'dedicated task tab', 'working tab', 'claim', 'stage/reason/next', 'in-app browser', 'Chrome readiness flow', 'Do not fail because')
  'framework/03-runtime/00-runtime-sequence.md' = @('Chrome readiness flow completed:', 'Chrome-family binding selected explicitly:', 'Dedicated task tab created', 'User working tab preserved:', 'Failure stage/reason/next recorded:', 'Emergency fallback authorization:', 'READY_LAST_RESORT', 'sameTargetProven', 'LOOPBACK_ONLY', 'Browser storage inspected: NO', 'Banner classification:', 'PARTIAL_VISUAL_GATE')
  'framework/29-checklists/32-browser-session-control-checklist.md' = @('exact returned object', 'Debugging/CDP authorization', 'READY_LAST_RESORT', 'cookies/storage/password/profile/history APIs were not used')
  'scripts/sync-runtime.ps1' = @('Chrome family explicitly', 'dedicated task tab', 'user.openTabs()', 'working tab unless explicitly requested', 'in-app browser', 'stage', 'reason', 'THREAD_CONTROL_CHANNEL_DEGRADED', 'AUTHORIZED_LOOPBACK_LAST_RESORT', 'repair-chrome-tab-ownership.ps1')
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
foreach ($relative in @('UEEF-LOADER.md','framework/51-browser-session-control/01-user-owned-browser.md','framework/51-browser-session-control/05-fallback-consent-and-blocking.md','framework/51-browser-session-control/09-platform-authorized-chrome-control.md','framework/51-browser-session-control/11-control-surface-selection.md','framework/51-browser-session-control/15-chrome-control-readiness.md','framework/51-browser-session-control/16-control-channel-failover.md','scripts/sync-runtime.ps1')) {
  $text = Get-Content -LiteralPath (Join-Path $root $relative) -Raw
  if ($text -notmatch 'macOS/Linux' -or $text -notmatch 'Windows-only|only on Windows') { throw "Cross-platform browser fallback is incomplete in $relative." }
}
$generatedText = Get-Content -LiteralPath (Join-Path $root 'scripts/sync-runtime.ps1') -Raw
if ($generatedText -match 'Automation banners, Codex-titled browser windows, and unverified profiles are BLOCKED') { throw 'Obsolete banner-only browser block remains.' }
$forbiddenBrowserTerms = @('Active window identity verified:', 'Automation banner visible: NO / BLOCKED', 'currently visible browser window')
foreach ($term in $forbiddenBrowserTerms) {
  if ((Get-ChildItem -LiteralPath (Join-Path $root 'framework') -Recurse -File -Filter *.md | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -match [regex]::Escape($term)) { throw "Obsolete browser contract term remains: $term" }
}
$masterText = Get-Content -LiteralPath (Join-Path $root 'framework/01-core/01-master-loader.md') -Raw
if ($masterText -notmatch 'only when the user explicitly asks for browser/site/visual work' -or $masterText -notmatch 'mere mention of a browser') { throw 'Browser selection is not explicit and proportional.' }
$isolatedText = Get-Content -LiteralPath (Join-Path $root 'framework/51-browser-session-control/03-no-isolated-browser-by-default.md') -Raw
if ($isolatedText -match 'Isolated contexts are acceptable') { throw 'Isolated Chrome fallback remains.' }
$checklistText = Get-Content -LiteralPath (Join-Path $root 'framework/29-checklists/32-browser-session-control-checklist.md') -Raw
if ($checklistText -match 'Explicit consent recorded if an isolated fallback was necessary') { throw 'Consent-based isolated fallback remains.' }
$handoffText = Get-Content -LiteralPath (Join-Path $root 'framework/51-browser-session-control/12-cross-session-evidence-handoff.md') -Raw
if ($handoffText -notmatch 'Do not mark the task `BLOCKED`') { throw 'Cross-session evidence handoff does not prohibit false blocking.' }
$browserContractText = Get-ChildItem -LiteralPath (Join-Path $root 'framework/51-browser-session-control') -File -Filter *.md | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }
foreach ($term in @('wait for the user to say', 'ask the user to say', "say ``$arabicDone``", "say '$arabicDone'", "say `"$arabicDone`"")) {
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
if ($loaderText -notmatch 'explicit separate user request' -or $loaderText -notmatch 'dedicated task tab' -or $loaderText -notmatch "user's working tab" -or $loaderText -notmatch 'in-app browser') { throw 'Loader does not constrain Chrome identity, dedicated-tab ownership, and isolated tests.' }
foreach ($relative in @('UEEF-LOADER.md','scripts/sync-runtime.ps1','framework/51-browser-session-control/00-browser-session-first.md')) {
  $text = Get-Content -LiteralPath (Join-Path $root $relative) -Raw
  foreach ($term in @('HARD FAIL BEFORE ANY BROWSER TOOL','get-ueef-task-preflight.ps1','browserGate','do not select a browser tool','mcp__node_repl__js','claimTab()','tab.playwright')) {
    if ($text -notmatch [regex]::Escape($term)) { throw "Mandatory pre-tool browser gate term '$term' missing from $relative." }
  }
}
$preflightText = Get-Content -LiteralPath (Join-Path $root 'scripts/get-ueef-task-preflight.ps1') -Raw
foreach ($term in @("status = 'REQUIRED'", "enforcement = 'HARD_FAIL_BEFORE_BROWSER_TOOL'", 'requiredBeforeTool', 'allowedPath', 'forbiddenSurfaces', 'taskTabPolicy', 'DEDICATED_TAB_SAME_CHROME_WINDOW_PROFILE_SESSION', 'failureReporting', 'genericChannelFailureForbidden', 'agent.browsers.get("chrome")', 'agent.browsers.getDefault()', 'agent.browsers.get("iab")', 'emergencyFallback', 'AUTHORIZED_LOOPBACK_LAST_RESORT', 'READY_LAST_RESORT', 'hostRulesWin', 'Do not select or call a browser tool')) {
  if ($preflightText -notmatch [regex]::Escape($term)) { throw "Structured browser preflight gate term '$term' missing." }
}
$browserPolicyText = (@('UEEF-LOADER.md','framework/51-browser-session-control/04-browser-and-tab-selection.md','framework/51-browser-session-control/11-control-surface-selection.md','framework/51-browser-session-control/15-chrome-control-readiness.md') | ForEach-Object { Get-Content -LiteralPath (Join-Path $root $_) -Raw }) -join "`n"
foreach($term in @('dedicated task tab','same existing window/profile/session','working tab','in-app browser','stage','reason','next')){if($browserPolicyText -notmatch [regex]::Escape($term)){throw "Dedicated-tab browser policy term missing: $term"}}

$fallbackPolicy = Get-Content -LiteralPath (Join-Path $root 'config/browser-emergency-fallback.json') -Raw | ConvertFrom-Json
if($fallbackPolicy.schemaVersion -ne 1 -or !$fallbackPolicy.enabled -or $fallbackPolicy.mode -ne 'explicit-last-resort' -or !$fallbackPolicy.requiresExplicitUserAuthorization -or !$fallbackPolicy.existingBrowserOnly -or !$fallbackPolicy.sameTargetRequired){throw 'Browser emergency fallback policy is not fail-closed.'}
foreach($loopbackHost in @('127.0.0.1','localhost','::1')){if($loopbackHost -notin @($fallbackPolicy.allowedHosts)){throw "Loopback host missing from emergency fallback policy: $loopbackHost"}}
foreach($term in @('launch-browser','create-profile','create-context','inspect-cookies','inspect-storage','inspect-passwords','inspect-profile-directory','bind-non-loopback')){if($term -notin @($fallbackPolicy.forbidden)){throw "Emergency fallback prohibition missing: $term"}}
& (Join-Path $root 'scripts/test-remote-debugging-readiness.ps1') | Out-Null
foreach ($relative in @('QUICK_START.md','INSTALL.md')) {
  $text = Get-Content -LiteralPath (Join-Path $root $relative) -Raw
  foreach ($term in @('sync-runtime','still opens or proposes another browser','immediately')) {
    if ($text -notmatch [regex]::Escape($term)) { throw "Browser runtime-sync guidance '$term' missing from $relative." }
  }
}

. (Join-Path $root 'scripts/resolve-codex-home.ps1')
$previousCodexHome = $env:CODEX_HOME
$tempCodexHome = $null
try {
  if (!$env:CODEX_HOME) {
    $tempCodexHome = Join-Path ([IO.Path]::GetTempPath()) ("ueef-browser-contract-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempCodexHome -Force | Out-Null
    $env:CODEX_HOME = $tempCodexHome
  }
  $bootstrapOutput = (& (Join-Path $root 'scripts/environment-bootstrap.ps1') 2>&1 | Out-String)
  if ($bootstrapOutput -match 'Collection was of a fixed size') { throw 'Default environment bootstrap still uses a fixed-size collection.' }
} finally {
  $env:CODEX_HOME = $previousCodexHome
  if ($tempCodexHome -and (Test-Path -LiteralPath $tempCodexHome)) { Remove-Item -LiteralPath $tempCodexHome -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host 'Browser control contract tests passed'
