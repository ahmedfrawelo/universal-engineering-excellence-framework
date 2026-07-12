param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$Json,
  [string]$ReportPath
)
$ErrorActionPreference = 'Stop'
$resolvedRoot = (Resolve-Path $Root).Path
$results = [System.Collections.Generic.List[object]]::new()
function Check($name, [scriptblock]$action) {
  try { & $action; $results.Add([pscustomobject]@{ name = $name; status = 'PASS' }) }
  catch { $results.Add([pscustomobject]@{ name = $name; status = 'FAIL'; detail = $_.Exception.Message }) }
}
Check 'framework-validation' { & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $resolvedRoot 'scripts/validate-framework.ps1') | Out-Null }
Check 'git-clean-diff' { git -C $resolvedRoot diff --check | Out-Null; if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed' } }
Check 'source-hygiene' {
  $bad = Get-ChildItem $resolvedRoot -Recurse -File -Force | Where-Object { $_.FullName -notmatch '\\.git\\' -and $_.Name -match '(\.env$|\.pem$|\.key$|id_rsa)' }
  if ($bad) { throw "Sensitive-looking files present: $($bad.Name -join ', ')" }
  $secretPatterns = '-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}'
  $matches = @(git -C $resolvedRoot grep -n -I -E -e $secretPatterns -- . ':(exclude)scripts/ueef-audit.ps1' ':(exclude)scripts/ueef-audit.sh' 2>$null)
  if ($LASTEXITCODE -eq 0 -and $matches.Count) { throw "Secret-like tracked content found: $($matches[0])" }
  if ($LASTEXITCODE -notin @(0,1)) { throw 'Tracked secret scan failed' }
}
Check 'tracked-generated-artifacts' {
  $tracked = @(git -C $resolvedRoot ls-files -- 'dist' 'build' 'coverage' 'test-results' 'playwright-report' '*.log' '*.tmp')
  if ($tracked.Count) { throw "Generated artifacts tracked: $($tracked -join ', ')" }
}
Check 'script-syntax' {
  Get-ChildItem (Join-Path $resolvedRoot 'scripts') -Filter '*.ps1' | ForEach-Object {
    $tokens = $null; $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count) { throw "PowerShell parse errors in $($_.Name)" }
  }
  Get-ChildItem (Join-Path $resolvedRoot 'scripts') -Filter '*.mjs' | ForEach-Object { & node --check $_.FullName | Out-Null }
}
Check 'release-parity' {
  $manifest = Get-Content (Join-Path $resolvedRoot 'release-manifest.json') -Raw | ConvertFrom-Json
  $version = [regex]::Match((Get-Content (Join-Path $resolvedRoot 'VERSION.md') -Raw), '\b\d+\.\d+\.\d+\b').Value
  if ($manifest.version -ne $version) { throw "Version mismatch: $version vs $($manifest.version)" }
}
Check 'runtime-path-safety' {
  $sync = Get-Content (Join-Path $resolvedRoot 'scripts/sync-runtime.ps1') -Raw
  foreach ($term in @('Refusing to sync from inside CODEX_HOME', 'runtimePrefix', 'OrdinalIgnoreCase')) { if ($sync -notmatch [regex]::Escape($term)) { throw "Missing path safety control: $term" } }
}
Check 'runtime-hardening' { & (Join-Path $resolvedRoot 'scripts/test-runtime-hardening.ps1') | Out-Null }
$summary = [pscustomobject]@{ generatedAt = (Get-Date).ToUniversalTime().ToString('o'); root = '<project-root>'; checks = $results; status = if (($results.status -contains 'FAIL')) { 'FAIL' } else { 'PASS' } }
if ($ReportPath) { $summary | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 $ReportPath }
if ($Json) { $summary | ConvertTo-Json -Depth 5 } else { $results | Format-Table -AutoSize; Write-Host "UEEF audit: $($summary.status)" }
if ($summary.status -eq 'FAIL') { exit 1 }
