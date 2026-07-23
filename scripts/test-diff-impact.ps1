$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$result=(& (Join-Path $root 'scripts\get-diff-impact.ps1') -RepositoryPath $root -Base HEAD -Json|Out-String)|ConvertFrom-Json
if($result.schemaVersion -ne 1 -or $result.impact.confidence -notin @('HEURISTIC','NONE')){throw 'Diff impact contract failed.'}
Write-Host 'Diff impact tests passed'
