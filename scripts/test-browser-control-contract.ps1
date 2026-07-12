$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$required = @{
  'UEEF-LOADER.md' = @('user.openTabs()', 'claimTab()', 'plugin is unavailable')
  'framework/01-core/01-master-loader.md' = @('user.openTabs()', 'claimTab()')
  'framework/51-browser-session-control/04-browser-and-tab-selection.md' = @('exact returned object', 'claimTab()')
  'framework/51-browser-session-control/11-control-surface-selection.md' = @('Chrome plugin extension binding', 'visible Windows control only when')
  'framework/27-quality-gates/23-browser-session-control-gate.md' = @('user.openTabs()', 'claimTab()', 'Do not fail merely')
  'framework/29-checklists/32-browser-session-control-checklist.md' = @('exact returned object', 'Debugging/CDP authorization')
  'scripts/sync-runtime.ps1' = @('user.openTabs()', 'claimTab()', 'Extension attachment')
}
foreach ($relative in $required.Keys) {
  $text = Get-Content -LiteralPath (Join-Path $root $relative) -Raw
  foreach ($term in $required[$relative]) {
    if ($text -notmatch [regex]::Escape($term)) { throw "Browser contract term '$term' missing from $relative." }
  }
}

$policyText = Get-Content -LiteralPath (Join-Path $root 'framework/51-browser-session-control/11-control-surface-selection.md') -Raw
if ($policyText -match 'prefer verified visible Windows control') { throw 'Obsolete Windows-first Chrome policy remains.' }

$previousCodexHome = $env:CODEX_HOME
try {
  if (!$env:CODEX_HOME) { $env:CODEX_HOME = 'E:\shared folder\codex-home' }
  $bootstrapOutput = (& (Join-Path $root 'scripts/environment-bootstrap.ps1') 2>&1 | Out-String)
  if ($bootstrapOutput -match 'Collection was of a fixed size') { throw 'Default environment bootstrap still uses a fixed-size collection.' }
} finally {
  $env:CODEX_HOME = $previousCodexHome
}

Write-Host 'Browser control contract tests passed'
