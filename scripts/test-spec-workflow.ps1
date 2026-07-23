$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('ueef-spec-workflow-' + [guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory -Path $sandbox | Out-Null
  $new = Join-Path $root 'scripts\new-spec-workflow.ps1'
  $validate = Join-Path $root 'scripts\validate-spec-workflow.ps1'
  $created = & $new -Id 'demo-feature' -Root $sandbox | ConvertFrom-Json
  if ($created.schemaVersion -ne 1 -or !(Test-Path -LiteralPath $created.path)) { throw 'Workflow generator did not produce its contract.' }
  & $validate -Path $created.path -Mode Draft | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Validator rejected a newly generated draft.' }
  & $validate -Path $created.path -Mode Ready | Out-Null
  if ($LASTEXITCODE -eq 0) { throw 'Validator accepted unresolved workflow placeholders.' }
  Get-ChildItem -LiteralPath $created.path -File | ForEach-Object {
    $text = Get-Content -LiteralPath $_.FullName -Raw
    $text = [regex]::Replace($text, '\{\{[A-Z0-9_]+\}\}', 'Completed')
    $text = $text -replace '\| AC-001 \| Completed \| Completed \| Completed \|', '| AC-001 | completed review | PASS | 2026-07-23T00:00:00Z |'
    Set-Content -LiteralPath $_.FullName -Value $text -Encoding utf8
  }
  & $validate -Path $created.path -Mode Ready | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Validator rejected a completed workflow.' }
  $duplicateRejected = $false
  try { & $new -Id 'demo-feature' -Root $sandbox | Out-Null } catch { $duplicateRejected = $true }
  if (!$duplicateRejected) { throw 'Generator overwrote an existing workflow without -Force.' }
  Write-Host 'Spec workflow tests passed'
} finally {
  if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
