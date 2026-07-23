$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$result=(& (Join-Path $root 'scripts\get-diff-impact.ps1') -RepositoryPath $root -Base HEAD -Json|Out-String)|ConvertFrom-Json
if($result.schemaVersion -ne 2 -or $result.impact.confidence -notin @('MODERATE','HEURISTIC','NONE') -or $result.limitations -notmatch 'not a complete dependency graph' -or $null -eq $result.impact.sharedOwners -or $null -eq $result.impact.contractSignals) {throw 'Diff impact contract failed.'}
 $human=& (Join-Path $root 'scripts\get-diff-impact.ps1') -RepositoryPath $root -Base HEAD
if(($human -join "`n") -notmatch 'Confidence:' -or ($human -join "`n") -notmatch 'Limitations:'){throw 'Diff impact human output lacks transparency.'}
Write-Host 'Diff impact tests passed'
