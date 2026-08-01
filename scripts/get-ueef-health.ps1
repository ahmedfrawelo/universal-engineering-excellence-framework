[CmdletBinding()]
param(
  [string]$RepositoryPath = '',
  [string]$GlobalPath = '',
  [string]$CodexHome = '',
  [string]$ConfigPath,
  [string]$RegistryPath = '',
  [switch]$IncludeRuntimeDrift,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $PSCommandPath
. (Join-Path $scriptRoot 'resolve-codex-home.ps1')
if ([string]::IsNullOrWhiteSpace($RepositoryPath)) { $RepositoryPath = Split-Path -Parent $scriptRoot }
try {
  $RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath -ErrorAction Stop).Path
} catch {
  throw "RepositoryPath does not exist: $RepositoryPath"
}
if ([string]::IsNullOrWhiteSpace($CodexHome)) {
  $CodexHome = if ((Split-Path -Leaf $RepositoryPath) -eq 'codex' -and (Split-Path -Leaf (Split-Path -Parent $RepositoryPath)) -eq 'ueef') { Split-Path -Parent (Split-Path -Parent $RepositoryPath) } else { Resolve-CodexHome }
}
if ([string]::IsNullOrWhiteSpace($RegistryPath)) { $RegistryPath = Join-Path (Split-Path -Parent $scriptRoot) 'config\capability-registry.json' }
$statusScript = Join-Path $scriptRoot 'ueef-status.ps1'
$capabilityScript = Join-Path $scriptRoot 'get-capability-health.ps1'
$statusArgs = @{ RepositoryPath=$RepositoryPath; GlobalPath=$GlobalPath; Json=$true; SkipRuntimeDrift=(-not $IncludeRuntimeDrift) }
$runtime = (& $statusScript @statusArgs | Out-String) | ConvertFrom-Json
$capabilityArgs = @{ CodexHome=$CodexHome; RegistryPath=$RegistryPath; Json=$true }
if ($ConfigPath) { $capabilityArgs.ConfigPath = $ConfigPath }
$capabilities = @(((& $capabilityScript @capabilityArgs | Out-String) | ConvertFrom-Json) | ForEach-Object { $_ })
$diagnostics = [Collections.Generic.List[object]]::new()
if ($runtime.mode -eq 'source-checkout' -and $runtime.overall -eq 'SOURCE_VALIDATED') {
  $diagnostics.Add([pscustomobject]@{id='source-checkout-not-installed';severity='INFO';status=$runtime.overall;source='ueef-status';detail='The source checkout passes repository validation but is not an installed managed runtime.';action='Run scripts/sync-runtime.ps1 with the intended Codex home before relying on runtime activation.'})
} elseif ($runtime.overall -notin @('ACTIVE','SOURCE_VALIDATED')) {
  $diagnostics.Add([pscustomobject]@{id='runtime-inactive';severity='ERROR';status=$runtime.overall;source='ueef-status';detail='Runtime activation or integrity checks failed.';action='Run scripts/ueef-status.ps1 and repair the failing runtime check before using deep workflows.'})
}
foreach ($capability in $capabilities) {
  if ($capability.required -and $capability.health -in @('MISSING_DEPENDENCY','DISABLED','NOT_CONFIGURED')) { $diagnostics.Add([pscustomobject]@{id="required-$($capability.type)-$($capability.name)";severity='ERROR';status=$capability.health;source='capability-doctor';detail=$capability.detail;action=$capability.fallback}) }
  elseif (!$capability.required -and $capability.health -in @('MISSING_DEPENDENCY','DISABLED','NOT_CONFIGURED')) { $diagnostics.Add([pscustomobject]@{id="optional-$($capability.type)-$($capability.name)";severity='WARN';status=$capability.health;source='capability-doctor';detail=$capability.detail;action=$capability.fallback}) }
  elseif ($capability.health -eq 'DEGRADED') { $diagnostics.Add([pscustomobject]@{id="degraded-$($capability.type)-$($capability.name)";severity=if($capability.required){'ERROR'}else{'WARN'};status=$capability.health;source='capability-doctor';detail=$capability.detail;action='Repair or update the installed capability manifest, then rerun capability health.'}) }
}
$overall = if ($diagnostics.severity -contains 'ERROR') { 'FAIL' } elseif ($diagnostics.severity -contains 'WARN') { 'DEGRADED' } else { 'PASS' }
$counts = @{}
foreach ($group in $capabilities | Group-Object health) { $counts[$group.Name] = $group.Count }
$result = [ordered]@{ schemaVersion=2; generatedAt=(Get-Date).ToUniversalTime().ToString('o'); overall=[ordered]@{status=$overall}; runtime=$runtime; capabilities=[ordered]@{summary=$counts;items=$capabilities}; diagnostics=@($diagnostics) }
if ($Json) { $result | ConvertTo-Json -Depth 8 } else { Write-Output "UEEF Health: $overall"; Write-Output "Runtime: $($runtime.overall) ($($runtime.version))"; Write-Output "Capabilities: $(($counts.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '; ')"; if($diagnostics.Count){$diagnostics | ForEach-Object { Write-Output "$($_.severity): $($_.id) -> $($_.action)" }} }
if ($overall -eq 'FAIL') { exit 1 }
exit 0
