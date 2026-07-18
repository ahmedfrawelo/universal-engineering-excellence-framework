param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'

$temp = Join-Path ([IO.Path]::GetTempPath()) ("ueef-audit-failure-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path (Join-Path $temp 'scripts') -Force | Out-Null
try {
  Set-Content -LiteralPath (Join-Path $temp 'scripts/validate-framework.ps1') -Value 'exit 7' -Encoding utf8
  $ErrorActionPreference = 'Continue'
  $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'scripts/ueef-audit.ps1') -Root $temp -Quick 2>&1 | Out-String
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  if ($exitCode -eq 0) { throw 'UEEF audit returned success for a failing external validator' }
  if ($output -notmatch 'framework-validation\s+FAIL') { throw 'UEEF audit did not report framework-validation FAIL' }
} finally {
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'Continuous assurance failure propagation tests passed'
$global:LASTEXITCODE = 0
