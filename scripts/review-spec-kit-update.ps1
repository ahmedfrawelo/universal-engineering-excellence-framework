[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$CandidatePath,
  [string]$EngineRoot = (Join-Path $PSScriptRoot '..\engines\spec-workflow')
)

$ErrorActionPreference = 'Stop'
$candidate = (Resolve-Path -LiteralPath $CandidatePath).Path
$engine = (Resolve-Path -LiteralPath $EngineRoot).Path
$current = Join-Path $engine 'upstream\spec-kit'
if ($candidate -eq $current) { throw 'Candidate must be separate from the installed snapshot.' }
foreach ($required in @('LICENSE', 'README.md', 'pyproject.toml')) {
  if (!(Test-Path -LiteralPath (Join-Path $candidate $required) -PathType Leaf)) {
    throw "Candidate is missing $required"
  }
}
$files = Get-ChildItem -LiteralPath $candidate -Recurse -File | Sort-Object FullName
if (!$files) { throw 'Candidate snapshot is empty.' }
$records = foreach ($file in $files) {
  $relative = $file.FullName.Substring($candidate.Length).TrimStart('\', '/').Replace('\', '/')
  $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  [pscustomobject]@{ path = $relative; sha256 = $hash; bytes = $file.Length }
}
$payload = ($records | ConvertTo-Json -Depth 3 -Compress)
$hasher = [Security.Cryptography.SHA256]::Create()
try {
  $digest = -join ($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($payload)) | ForEach-Object { $_.ToString('x2') })
} finally {
  $hasher.Dispose()
}
[pscustomobject]@{
  schemaVersion = 1
  status = 'REVIEW_REQUIRED'
  currentSnapshot = $current
  candidateSnapshot = $candidate
  fileCount = $records.Count
  reviewDigest = $digest
  mutatesCurrentSnapshot = $false
  requiredNextGates = @('license-review', 'provenance-review', 'compatibility-tests', 'explicit-replacement')
} | ConvertTo-Json -Depth 4
