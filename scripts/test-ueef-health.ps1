[CmdletBinding()]
param(
  [string]$RuntimePath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'resolve-codex-home.ps1')
if ([string]::IsNullOrWhiteSpace($RuntimePath)) {
  $RuntimePath = if ($env:UEEF_TEST_RUNTIME) { $env:UEEF_TEST_RUNTIME } else { Resolve-UeefCodexRuntimePath }
}
$healthScript = Join-Path $RuntimePath 'scripts\get-ueef-health.ps1'
if (!(Test-Path -LiteralPath $healthScript)) { throw "Health script not found: $healthScript" }

$result = (& $healthScript -RepositoryPath $RuntimePath -GlobalPath (Split-Path -Parent $RuntimePath) -CodexHome (Split-Path -Parent (Split-Path -Parent $RuntimePath)) -Json | Out-String) | ConvertFrom-Json
if ($result.schemaVersion -ne 1) { throw 'Expected health schemaVersion 1.' }
if ($result.runtime.overall -ne 'ACTIVE') { throw "Expected active runtime, received $($result.runtime.overall)." }
if ($result.overall.status -notin @('PASS', 'DEGRADED')) { throw "Expected usable health status, received $($result.overall.status)." }
if ($null -eq $result.capabilities.items -or @($result.capabilities.items).Count -lt 1) { throw 'Expected capability inventory items.' }
if ($result.diagnostics | Where-Object { $_.severity -eq 'ERROR' }) { throw 'Expected no health-report errors for the active runtime.' }

Write-Output 'UEEF health tests PASS'
