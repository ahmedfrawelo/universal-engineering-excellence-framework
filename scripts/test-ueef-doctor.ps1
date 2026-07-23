$ErrorActionPreference = 'Stop'
$doctor = Join-Path $PSScriptRoot 'ueef-doctor.ps1'
$result = (& $doctor -RuntimePath (Join-Path $env:TEMP 'missing-ueef-runtime') -Json | Out-String) | ConvertFrom-Json
if ($result.runtimeInstalled -or $result.intentTermsPresent -or $result.recommendation -notmatch 'sync-runtime') { throw 'UEEF doctor must honestly report a missing runtime and a sync recommendation.' }
Write-Host 'UEEF doctor tests passed'
