param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$Json,
  [string]$ReportPath,
  [switch]$Quick,
  [switch]$Detailed
)
$ErrorActionPreference = 'Stop'
$resolvedRoot = (Resolve-Path $Root).Path
$gitRoot = $resolvedRoot
if (!(Test-Path -LiteralPath (Join-Path $gitRoot '.git'))) {
  $statePath = Join-Path (Split-Path -Parent $resolvedRoot) 'UEEF-ACTIVE.json'
  if (Test-Path -LiteralPath $statePath) {
    try {
      $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
      $candidate = [string]$state.sourceRepositoryPath
      if (Test-Path -LiteralPath (Join-Path $candidate '.git')) { $gitRoot = (Resolve-Path -LiteralPath $candidate).Path }
    } catch { }
  }
}
$results = [System.Collections.Generic.List[object]]::new()
function Check($name, [scriptblock]$action) {
  $duration = [System.Diagnostics.Stopwatch]::StartNew()
  try {
    & $action
    $duration.Stop()
    $results.Add([pscustomobject]@{ name = $name; status = 'PASS'; durationMs = [int]$duration.ElapsedMilliseconds })
  }
  catch {
    $duration.Stop()
    $results.Add([pscustomobject]@{ name = $name; status = 'FAIL'; durationMs = [int]$duration.ElapsedMilliseconds; detail = $_.Exception.Message })
  }
}
Check 'framework-validation' {
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $resolvedRoot 'scripts/validate-framework.ps1') -SkipNestedTests | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Framework validator exited with code $LASTEXITCODE" }
}
Check 'git-clean-diff' { if (!(Test-Path -LiteralPath (Join-Path $gitRoot '.git'))) { throw 'Source Git repository unavailable' }; git -C $gitRoot diff --check | Out-Null; if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed' } }
Check 'source-hygiene' {
  $bad = Get-ChildItem $resolvedRoot -Recurse -File -Force | Where-Object {
    $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.Name -match '(^\.env(?:\..+)?$|\.pem$|\.key$|\.pfx$|\.p12$|^id_(rsa|ed25519)$|^credentials\.json$|^service-account(?:-.+)?\.json$)'
  }
  if ($bad) { throw "Sensitive-looking files present: $($bad.Name -join ', ')" }
  $secretPatterns = '-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}'
  $matches = @(git -C $gitRoot grep -n -I -E -e $secretPatterns -- . ':(exclude)scripts/ueef-audit.ps1' ':(exclude)scripts/ueef-audit.sh' 2>$null)
  if ($LASTEXITCODE -eq 0 -and $matches.Count) { throw "Secret-like tracked content found: $($matches[0])" }
  if ($LASTEXITCODE -notin @(0,1)) { throw 'Tracked secret scan failed' }
}
Check 'tracked-generated-artifacts' {
  $tracked = @(git -C $gitRoot ls-files -- 'dist' 'build' 'coverage' 'test-results' 'playwright-report' '*.log' '*.tmp')
  if ($tracked.Count) { throw "Generated artifacts tracked: $($tracked -join ', ')" }
}
Check 'script-syntax' {
  & (Join-Path $resolvedRoot 'scripts/test-script-syntax.ps1') | Out-Null
}
Check 'release-parity' {
  & (Join-Path $resolvedRoot 'scripts/test-release-consistency.ps1') -Root $resolvedRoot | Out-Null
}
Check 'project-context-map' {
  & (Join-Path $resolvedRoot 'scripts/test-project-context-map.ps1') | Out-Null
}
Check 'documentation-paths' {
  & node (Join-Path $resolvedRoot 'scripts/test-documentation-links.mjs') $resolvedRoot | Out-Null
}
Check 'framework-indexes' {
  & node (Join-Path $resolvedRoot 'scripts/test-framework-indexes.mjs') $resolvedRoot | Out-Null
}
Check 'runtime-path-safety' {
  $sandbox = Join-Path ([IO.Path]::GetTempPath()) ('ueef-audit-path-' + [guid]::NewGuid().ToString('N'))
  try {
    $source = Join-Path $sandbox 'source'; New-Item -ItemType Directory -Path (Join-Path $source 'framework') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $source 'VERSION.md') -Value 'version: 0.0.0.'
    $rejected = $false
    try { & (Join-Path $resolvedRoot 'scripts/sync-runtime.ps1') -SourcePath $source -CodexHome (Join-Path $source 'codex-home') -Agent audit | Out-Null } catch { $rejected = $_.Exception.Message -like '*overlapping source and CODEX_HOME*' }
    if (!$rejected) { throw 'Runtime accepted an overlapping source and CODEX_HOME.' }
  } finally { if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force } }
}
if (!$Quick) {
  Check 'runtime-hardening' {
    & (Join-Path $resolvedRoot 'scripts/test-runtime-hardening.ps1') | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Runtime hardening tests exited with code $LASTEXITCODE" }
  }
}
$summary = [pscustomobject]@{ generatedAt = (Get-Date).ToUniversalTime().ToString('o'); root = '<project-root>'; checks = $results; status = if (($results.status -contains 'FAIL')) { 'FAIL' } else { 'PASS' } }
if ($ReportPath) { $summary | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 $ReportPath }
if ($Json) {
  $summary | ConvertTo-Json -Depth 5
} elseif ($Detailed -or $summary.status -eq 'FAIL') {
  $results | Format-Table -AutoSize
  Write-Host "UEEF audit: $($summary.status)"
} else {
  Write-Host "UEEF audit: PASS ($($results.Count) checks; use -Detailed for per-check output)"
}
if ($summary.status -eq 'FAIL') { exit 1 }
exit 0
