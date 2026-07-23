$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('ueef-assurance-budget-' + [guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory -Path $sandbox | Out-Null
  $measure = Join-Path $root 'scripts\measure-assurance.ps1'
  $passing = Join-Path $sandbox 'passing.json'
  @{ status='PASS'; checks=@(@{name='framework-validation';durationMs=100},@{name='script-syntax';durationMs=100}) } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $passing -Encoding utf8
  $result = & $measure -Root $root -Mode Quick -SummaryPath $passing | ConvertFrom-Json
  if (!$result.withinBudget -or $result.totalDurationMs -ne 200) { throw 'Budget evaluator rejected valid fixture.' }
  $slow = Join-Path $sandbox 'slow.json'
  @{ status='PASS'; checks=@(@{name='framework-validation';durationMs=30001}) } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $slow -Encoding utf8
  $slowResult = & $measure -Root $root -Mode Quick -SummaryPath $slow | ConvertFrom-Json
  if ($slowResult.withinBudget -or $slowResult.violations.Count -eq 0) { throw 'Budget evaluator accepted an over-budget fixture.' }
  & $measure -Root $root -Mode Quick -SummaryPath $slow -Enforce | Out-Null
  if ($LASTEXITCODE -eq 0) { throw 'Enforced budget accepted an over-budget fixture.' }
  $failed = Join-Path $sandbox 'failed.json'
  @{ status='FAIL'; checks=@(@{name='framework-validation';durationMs=100}) } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $failed -Encoding utf8
  $failedResult = & $measure -Root $root -Mode Quick -SummaryPath $failed | ConvertFrom-Json
  if ($failedResult.withinBudget) { throw 'Budget evaluator accepted a failed audit fixture.' }
  Write-Host 'Assurance performance tests passed'
} finally {
  if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
exit 0
