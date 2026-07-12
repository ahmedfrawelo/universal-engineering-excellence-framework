$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$required = @{
  'UEEF-LOADER.md' = @('save-contract bugs', 'Repetition does not convert', 'Never pause an incomplete code path')
  'framework/01-core/14-delivery-continuation-policy.md' = @('Internal implementation failures are never a real impasse', 'Repetition does not convert', 'no meaningful local implementation', 'BLOCKED_ALLOWED', 'repeated_external_condition')
  'scripts/sync-runtime.ps1' = @('save-contract bugs', 'external or user-only condition', 'never wait for the user merely to resume incomplete code')
}
foreach ($relative in $required.Keys) {
  $text = Get-Content -LiteralPath (Join-Path $root $relative) -Raw
  foreach ($term in $required[$relative]) {
    if ($text -notmatch [regex]::Escape($term)) { throw "Delivery continuation term '$term' missing from $relative." }
  }
}
$guardianText = (Get-ChildItem -LiteralPath (Join-Path $root 'framework/49-engineering-guardian') -File -Filter *.md | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
if ($guardianText -match 'must stop the task') { throw 'Engineering Guardian still allows regressions to stop implementation work.' }
if ($guardianText -notmatch 'must block completion and release claims') { throw 'Engineering Guardian continuation wording is missing.' }
Write-Host 'Delivery continuation contract tests passed'
