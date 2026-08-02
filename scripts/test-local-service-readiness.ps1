$ErrorActionPreference='Stop'
$probe=Join-Path $PSScriptRoot 'get-local-service-readiness.ps1'
function Get-Case([string]$State,[switch]$Ownership){((& $probe -ProjectPath (Split-Path -Parent $PSScriptRoot) -Port 4200 -ProbeState $State -AllowSyntheticProbe -SyntheticOwnershipProven:$Ownership -Json)|Out-String)|ConvertFrom-Json}
$healthy=Get-Case 'ListeningHealthy' -Ownership
if($healthy.status -ne 'REUSE_EXISTING' -or !$healthy.reuseExisting -or $healthy.startAllowed){throw 'Healthy existing service was not reused.'}
$healthyUnknown=Get-Case 'ListeningHealthy'
if($healthyUnknown.status -ne 'OCCUPIED_UNVERIFIED' -or $healthyUnknown.reuseExisting){throw 'Healthy but unowned listener was incorrectly reused.'}
$missing=Get-Case 'NotListening'
if($missing.status -ne 'START_ALLOWED' -or !$missing.startAllowed -or $missing.reuseExisting){throw 'Absent service did not allow one start.'}
$unhealthy=Get-Case 'ListeningUnhealthy'
if($unhealthy.status -ne 'EXISTING_UNHEALTHY' -or $unhealthy.startAllowed){throw 'Unhealthy existing listener incorrectly allowed a duplicate start.'}
$unverified=((& $probe -ProjectPath (Split-Path -Parent $PSScriptRoot) -Port 4200 -ProbeState ListeningUnhealthy -AllowSyntheticProbe -Json)|Out-String)|ConvertFrom-Json
if($unverified.requiredAction -notmatch 'do not start a duplicate'){throw 'Duplicate-service prohibition is missing.'}
Write-Host 'Local service readiness tests passed'
