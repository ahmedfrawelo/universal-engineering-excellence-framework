[CmdletBinding()]
param(
  [string]$RepositoryPath = (Split-Path -Parent $PSScriptRoot),
  [string]$GlobalPath = '',
  [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } elseif ((Split-Path -Leaf $RepositoryPath) -eq 'codex' -and (Split-Path -Leaf (Split-Path -Parent $RepositoryPath)) -eq 'ueef') { Split-Path -Parent (Split-Path -Parent $RepositoryPath) } else { Join-Path $env:USERPROFILE '.codex' }),
  [string]$ConfigPath,
  [string]$RegistryPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'config\capability-registry.json'),
  [switch]$IncludeRuntimeDrift,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$statusScript = Join-Path $PSScriptRoot 'ueef-status.ps1'
$capabilityScript = Join-Path $PSScriptRoot 'get-capability-health.ps1'
$statusArgs = @{ RepositoryPath=$RepositoryPath; GlobalPath=$GlobalPath; Json=$true; SkipRuntimeDrift=(-not $IncludeRuntimeDrift) }
$runtime = (& $statusScript @statusArgs | Out-String) | ConvertFrom-Json
$capabilityArgs = @{ CodexHome=$CodexHome; RegistryPath=$RegistryPath; Json=$true }
if ($ConfigPath) { $capabilityArgs.ConfigPath = $ConfigPath }
$capabilities = @(((& $capabilityScript @capabilityArgs | Out-String) | ConvertFrom-Json) | ForEach-Object { $_ })
$diagnostics = [Collections.Generic.List[object]]::new()
if ($runtime.overall -ne 'ACTIVE') { $diagnostics.Add([pscustomobject]@{id='runtime-inactive';severity='ERROR';status=$runtime.overall;source='ueef-status';detail='Runtime activation or integrity checks failed.';action='Run ueeF status and repair the failing runtime check before using deep workflows.'}) }
foreach ($capability in $capabilities) {
  if ($capability.required -and $capability.health -in @('MISSING_DEPENDENCY','DISABLED','NOT_CONFIGURED')) { $diagnostics.Add([pscustomobject]@{id="required-$($capability.type)-$($capability.name)";severity='ERROR';status=$capability.health;source='capability-doctor';detail=$capability.detail;action=$capability.fallback}) }
  elseif (!$capability.required -and $capability.health -in @('MISSING_DEPENDENCY','DISABLED','NOT_CONFIGURED')) { $diagnostics.Add([pscustomobject]@{id="optional-$($capability.type)-$($capability.name)";severity='WARN';status=$capability.health;source='capability-doctor';detail=$capability.detail;action=$capability.fallback}) }
}
$overall = if ($diagnostics.severity -contains 'ERROR') { 'FAIL' } elseif ($diagnostics.severity -contains 'WARN') { 'DEGRADED' } else { 'PASS' }
$counts = @{}
foreach ($group in $capabilities | Group-Object health) { $counts[$group.Name] = $group.Count }
$result = [ordered]@{ schemaVersion=1; generatedAt=(Get-Date).ToUniversalTime().ToString('o'); overall=[ordered]@{status=$overall}; runtime=$runtime; capabilities=[ordered]@{summary=$counts;items=$capabilities}; diagnostics=@($diagnostics) }
if ($Json) { $result | ConvertTo-Json -Depth 8 } else { Write-Output "UEEF Health: $overall"; Write-Output "Runtime: $($runtime.overall) ($($runtime.version))"; Write-Output "Capabilities: $(($counts.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '; ')"; if($diagnostics.Count){$diagnostics | ForEach-Object { Write-Output "$($_.severity): $($_.id) -> $($_.action)" }} }
if ($overall -eq 'FAIL') { exit 1 }
exit 0
