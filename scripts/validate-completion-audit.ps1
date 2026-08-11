[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Path,
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
$output = & $node.Source $validator $resolved 2>&1
if ($LASTEXITCODE -ne 0) {
  throw (($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine)
}
$result = (($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine) | ConvertFrom-Json
if ($Json) { $result | ConvertTo-Json -Depth 3 -Compress } else { $result | Format-List }
