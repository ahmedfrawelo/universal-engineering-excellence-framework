$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$required = @{
  'UEEF-LOADER.md' = @('user.openTabs()', 'claimTab()', 'plugin is unavailable', 'minimized, background, or non-foreground')
  'framework/01-core/01-master-loader.md' = @('user.openTabs()', 'claimTab()')
  'framework/51-browser-session-control/04-browser-and-tab-selection.md' = @('exact returned object', 'claimTab()')
  'framework/51-browser-session-control/10-window-state-preservation.md' = @('minimized, background, or non-foreground', 'do not pause or block the goal')
  'framework/51-browser-session-control/11-control-surface-selection.md' = @('Chrome plugin extension binding', 'visible Windows control only when')
  'framework/27-quality-gates/23-browser-session-control-gate.md' = @('user.openTabs()', 'claimTab()', 'Do not fail because')
  'framework/03-runtime/00-runtime-sequence.md' = @('Exact user.openTabs() object claimed:', 'Banner classification:', 'PARTIAL_VISUAL_GATE')
  'framework/29-checklists/32-browser-session-control-checklist.md' = @('exact returned object', 'Debugging/CDP authorization')
  'scripts/sync-runtime.ps1' = @('user.openTabs()', 'claimTab()', 'Extension attachment', 'must not pause the goal')
}
foreach ($relative in $required.Keys) {
  $text = Get-Content -LiteralPath (Join-Path $root $relative) -Raw
  foreach ($term in $required[$relative]) {
    if ($text -notmatch [regex]::Escape($term)) { throw "Browser contract term '$term' missing from $relative." }
  }
}

$policyText = Get-Content -LiteralPath (Join-Path $root 'framework/51-browser-session-control/11-control-surface-selection.md') -Raw
if ($policyText -match 'prefer verified visible Windows control') { throw 'Obsolete Windows-first Chrome policy remains.' }
$generatedText = Get-Content -LiteralPath (Join-Path $root 'scripts/sync-runtime.ps1') -Raw
if ($generatedText -match 'Automation banners, Codex-titled browser windows, and unverified profiles are BLOCKED') { throw 'Obsolete banner-only browser block remains.' }
$forbiddenBrowserTerms = @('Active window identity verified:', 'Automation banner visible: NO / BLOCKED', 'currently visible browser window')
foreach ($term in $forbiddenBrowserTerms) {
  if ((Get-ChildItem -LiteralPath (Join-Path $root 'framework') -Recurse -File -Filter *.md | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -match [regex]::Escape($term)) { throw "Obsolete browser contract term remains: $term" }
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
