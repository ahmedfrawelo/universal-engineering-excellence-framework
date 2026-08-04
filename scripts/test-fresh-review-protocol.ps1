$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$validator = Join-Path $root 'scripts\validate-fresh-review-evidence.ps1'
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('ueef-fresh-review-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null

function Write-Fixture([string]$Name, [hashtable]$Override = @{}) {
  $hash = 'a' * 64
  $fixture = [ordered]@{
    schemaVersion = 1; taskId = 'fresh-review-fixture'; tier = 'T4'; status = 'PASS'
    review = [ordered]@{ mode='FRESH_CONTEXT_REQUIRED'; freshContext=$true; reviewerThreadId='review-thread'; implementationThreadIds=@('implement-thread'); role='independent reviewer'; modelCapability='Frontier'; reasoning='high'; sandboxPolicyType='read-only'; permissionProfileType='disabled'; verdict='ship'; reason='Reviewed the actual diff and passing checks.'; findings=@(); residualRisk='none' }
    reviewedChange = [ordered]@{ paths=@('scripts/example.ps1'); reviewedDiffSha256=$hash; postReviewDiffSha256=$hash; repositoryStateBeforeSha256=$hash; repositoryStateAfterSha256=$hash }
    verification = [ordered]@{ commands=@('pwsh scripts/test-example.ps1'); results=@('PASS') }
    fallback = [ordered]@{ used=$false; reason='' }
  }
  foreach ($key in $Override.Keys) { $fixture[$key] = $Override[$key] }
  $path = Join-Path $fixtureRoot "$Name.json"
  $fixture | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path -Encoding utf8
  return $path
}

try {
  $valid = Write-Fixture 'valid'
  & $validator -Path $valid | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Valid fresh review evidence did not pass.' }

  $changed = Get-Content -LiteralPath $valid -Raw | ConvertFrom-Json
  $changed.reviewedChange.postReviewDiffSha256 = 'b' * 64
  $changedPath = Join-Path $fixtureRoot 'changed-after-review.json'
  $changed | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $changedPath -Encoding utf8
  & $validator -Path $changedPath 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) { throw 'Changed-after-review evidence was accepted.' }

  $notFresh = Get-Content -LiteralPath $valid -Raw | ConvertFrom-Json
  $notFresh.review.freshContext = $false
  $notFreshPath = Join-Path $fixtureRoot 'not-fresh-t4.json'
  $notFresh | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $notFreshPath -Encoding utf8
  & $validator -Path $notFreshPath 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) { throw 'Non-fresh T4 evidence was accepted.' }

  $fallback = Get-Content -LiteralPath $valid -Raw | ConvertFrom-Json
  $fallback.tier = 'T3'; $fallback.review.mode = 'DIRECT_REVIEW_FALLBACK'; $fallback.review.freshContext = $false; $fallback.fallback.used = $true; $fallback.fallback.reason = 'No eligible independent review lane was exposed by the host.'
  $fallbackPath = Join-Path $fixtureRoot 'fallback-t3.json'
  $fallback | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $fallbackPath -Encoding utf8
  & $validator -Path $fallbackPath | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Documented T3 fallback did not pass.' }
  Write-Host 'Fresh review protocol tests passed'
} finally {
  if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}
