[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Path,
  [switch]$RefreshSourceHash,
  [switch]$Json
)
$ErrorActionPreference = 'Stop'
$validator = Join-Path $PSScriptRoot 'validate-completion-audit.mjs'
$node = Get-Command node -ErrorAction Stop
$resolved = if (Test-Path -LiteralPath $Path -PathType Leaf) {
  (Resolve-Path -LiteralPath $Path).Path
} else {
  $Path
}
if ($RefreshSourceHash) {
  if (!(Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "Completion audit not found: $resolved" }
  $item = Get-Item -LiteralPath $resolved -Force
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Refusing to update a linked completion audit: $resolved" }
  $audit = Get-Content -LiteralPath $resolved -Raw | ConvertFrom-Json
  $sourceText = [string]$audit.sourceReview.sourceText
  if ([string]::IsNullOrWhiteSpace($sourceText)) { throw 'sourceReview.sourceText must be populated before refreshing its hash.' }
  $bytes = [Text.Encoding]::UTF8.GetBytes($sourceText)
  $audit.sourceReview.sourceSha256 = ([BitConverter]::ToString(([Security.Cryptography.SHA256]::Create()).ComputeHash($bytes)).Replace('-','')).ToUpperInvariant()
  $temporary = "$resolved.$([guid]::NewGuid().ToString('N')).tmp"
  try {
    [IO.File]::WriteAllText($temporary, ($audit | ConvertTo-Json -Depth 100), [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporary -Destination $resolved -Force
  } finally {
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
  }
}
$output = & $node.Source $validator $resolved 2>&1
if ($LASTEXITCODE -ne 0) {
  throw (($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine)
}
$result = (($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine) | ConvertFrom-Json
if ($Json) { $result | ConvertTo-Json -Depth 3 -Compress } else { $result | Format-List }
