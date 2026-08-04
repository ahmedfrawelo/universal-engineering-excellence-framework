[CmdletBinding()]
param(
  [string]$RuntimePath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'resolve-codex-home.ps1')
if ([string]::IsNullOrWhiteSpace($RuntimePath)) {
  $RuntimePath = if ($env:UEEF_TEST_RUNTIME) { $env:UEEF_TEST_RUNTIME } else { Resolve-UeefCodexRuntimePath }
}
$RuntimePath = (Resolve-Path -LiteralPath $RuntimePath -ErrorAction Stop).Path
$healthScript = Join-Path $RuntimePath 'scripts\get-ueef-health.ps1'
if (!(Test-Path -LiteralPath $healthScript)) { throw "Health script not found: $healthScript" }

$healthArgs = @{ RepositoryPath = $RuntimePath; Json = $true }
if ((Split-Path -Leaf $RuntimePath) -eq 'codex' -and (Split-Path -Leaf (Split-Path -Parent $RuntimePath)) -eq 'ueef') {
  $healthArgs.GlobalPath = Split-Path -Parent $RuntimePath
  $healthArgs.CodexHome = Split-Path -Parent (Split-Path -Parent $RuntimePath)
}
$result = (& $healthScript @healthArgs | Out-String) | ConvertFrom-Json
if ($result.schemaVersion -ne 2) { throw 'Expected health schemaVersion 2.' }
if ($result.runtime.overall -notin @('ACTIVE','SOURCE_VALIDATED')) { throw "Expected active runtime or validated source, received $($result.runtime.overall)." }
if ($result.overall.status -notin @('PASS', 'DEGRADED')) { throw "Expected usable health status, received $($result.overall.status)." }
if ($null -eq $result.capabilities.items -or @($result.capabilities.items).Count -lt 1) { throw 'Expected capability inventory items.' }
if ($result.diagnostics | Where-Object { $_.severity -eq 'ERROR' }) { throw 'Expected no health-report errors for the active runtime.' }
if ($result.overall.PSObject.Properties.Name -notcontains 'warnings' -or $result.overall.PSObject.Properties.Name -notcontains 'blockingWarnings') { throw 'Expected warning counters in health overall summary.' }
if (@($result.diagnostics | Where-Object { $_.severity -eq 'WARN' }).Count -gt 0 -and $result.overall.blockingWarnings -eq 0 -and $result.overall.status -ne 'PASS') { throw 'Optional capability warnings must not degrade overall runtime health.' }

Write-Output 'UEEF health tests PASS'
