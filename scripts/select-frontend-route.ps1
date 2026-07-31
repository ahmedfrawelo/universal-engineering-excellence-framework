param(
  [Parameter(Mandatory=$true)][string]$Task,
  [ValidateSet('Auto','Quick','Build','Audit')][string]$Mode = 'Auto',
  [switch]$Json
)
$ErrorActionPreference = 'Stop'
$result = & node (Join-Path $PSScriptRoot 'select-frontend-route.mjs') --task $Task --mode $Mode
if ($LASTEXITCODE -ne 0) { throw 'Frontend route engine failed.' }
if ($Json) { $result } else { ($result | Out-String | ConvertFrom-Json) }
