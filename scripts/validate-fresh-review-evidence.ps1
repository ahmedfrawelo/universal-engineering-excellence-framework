[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Path,
  [switch]$Json,
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) { throw "FRESH_REVIEW_EVIDENCE: FAIL - $Message" }
function Test-Text($Value) {
  $text = [string]$Value
  return $text.Trim().Length -ge 3 -and $text.Trim() -notmatch '^(?i:todo|tbd|replace-me|null|none)$'
}
function Test-Sha256($Value) { return ([string]$Value) -match '^[a-fA-F0-9]{64}$' }

try {
  if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { Fail "Missing evidence: $Path" }
  $evidence = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
  if ($evidence.schemaVersion -ne 1) { Fail 'schemaVersion must be 1.' }
  if ($evidence.status -ne 'PASS') { Fail 'status must be PASS.' }
  if (!(Test-Text $evidence.taskId)) { Fail 'taskId must be substantive.' }
  if ([string]$evidence.tier -notin @('T3','T4')) { Fail 'tier must be T3 or T4.' }

  $review = $evidence.review
  if ($null -eq $review) { Fail 'review is required.' }
  $expectedMode = if ($evidence.tier -eq 'T4') { 'FRESH_CONTEXT_REQUIRED' } else { @('FRESH_CONTEXT_RECOMMENDED','FRESH_CONTEXT_REQUIRED','DIRECT_REVIEW_FALLBACK') }
  if ($review.mode -notin @($expectedMode)) { Fail "review.mode is invalid for tier $($evidence.tier)." }
  if ($review.verdict -notin @('ship','fix-first','rethink')) { Fail 'review.verdict must be ship, fix-first, or rethink.' }
  if (!(Test-Text $review.reason)) { Fail 'review.reason must be substantive.' }
  foreach ($field in @('role','modelCapability','sandboxPolicyType','permissionProfileType')) {
    if (!(Test-Text $review.$field)) { Fail "review.$field must be substantive." }
  }
  if ($review.verdict -ne 'ship') { Fail 'Only a ship verdict can support completion evidence.' }

  $implementationThreads = @($review.implementationThreadIds | ForEach-Object { [string]$_ } | Where-Object { Test-Text $_ })
  if ([bool]$review.freshContext) {
    if (!(Test-Text $review.reviewerThreadId)) { Fail 'Fresh review requires reviewerThreadId.' }
    if ($implementationThreads -contains [string]$review.reviewerThreadId) { Fail 'Fresh reviewerThreadId must differ from implementation threads.' }
  } elseif ($evidence.tier -eq 'T4') {
    Fail 'T4 requires a fresh-context reviewer.'
  } elseif ($evidence.fallback.used -ne $true -or !(Test-Text $evidence.fallback.reason)) {
    Fail 'A non-fresh T3 review requires an explicit fallback reason.'
  }

  $change = $evidence.reviewedChange
  if ($null -eq $change -or @($change.paths).Count -eq 0) { Fail 'reviewedChange.paths must identify reviewed paths.' }
  foreach ($field in @('reviewedDiffSha256','postReviewDiffSha256','repositoryStateBeforeSha256','repositoryStateAfterSha256')) {
    if (!(Test-Sha256 $change.$field)) { Fail "reviewedChange.$field must be a SHA-256 digest." }
  }
  if ([string]$change.reviewedDiffSha256 -cne [string]$change.postReviewDiffSha256) { Fail 'Any post-review change invalidates the verdict.' }
  if ($review.sandboxPolicyType -ne 'read-only' -and ([string]$change.repositoryStateBeforeSha256 -cne [string]$change.repositoryStateAfterSha256)) {
    Fail 'Behavioral read-only review requires identical repository state before and after review.'
  }
  if (@($evidence.verification.commands | Where-Object { Test-Text $_ }).Count -eq 0 -or @($evidence.verification.results | Where-Object { Test-Text $_ }).Count -eq 0) {
    Fail 'verification.commands and verification.results require substantive evidence.'
  }

  $result = [ordered]@{ schemaVersion=1; status='PASS'; taskId=$evidence.taskId; tier=$evidence.tier; mode=$review.mode; verdict=$review.verdict; evidencePath=(Resolve-Path -LiteralPath $Path).Path }
  if (!$Quiet) {
    if ($Json) { $result | ConvertTo-Json -Depth 4 } else { [pscustomobject]$result | Format-List | Out-String | Write-Host }
    Write-Host 'FRESH_REVIEW_EVIDENCE: PASS'
  }
  exit 0
} catch {
  if (!$Quiet) { [Console]::Error.WriteLine($_.Exception.Message) }
  exit 1
}
