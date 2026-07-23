[CmdletBinding()]
param(
  [string]$RepositoryPath = (Get-Location).Path,
  [string]$Base = 'HEAD',
  [switch]$Staged,
  [switch]$Json
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath (Join-Path $RepositoryPath '.git'))) { throw "Not a Git repository: $RepositoryPath" }
$args = @('-C',$RepositoryPath,'diff','--name-only')
if ($Staged) { $args += '--cached' } else { $args += $Base }
$files = @(& git @args | Where-Object { $_ })
$gates = [Collections.Generic.List[string]]::new(); $packs = [Collections.Generic.List[string]]::new(); $reasons = [Collections.Generic.List[string]]::new()
function Add-Unique($list,[string]$value){if(!$list.Contains($value)){$list.Add($value)}}
foreach($file in $files){
  if($file -match '\.(tsx|jsx|css|scss|html)$'){Add-Unique $packs '14-ui';Add-Unique $packs '15-ux';Add-Unique $gates 'ui-gate';Add-Unique $gates 'accessibility-gate';Add-Unique $reasons "UI-related file: $file"}
  if($file -match '\.(ps1|sh|mjs|js)$'){Add-Unique $gates 'testing-gate';Add-Unique $gates 'code-quality-gate';Add-Unique $reasons "Executable script: $file"}
  if($file -match '(?i)(auth|security|credential|token)'){Add-Unique $gates 'security-gate';Add-Unique $reasons "Security-sensitive path: $file"}
  if($file -match '(?i)(api|controller|route)'){Add-Unique $packs '13-api';Add-Unique $gates 'api-gate';Add-Unique $reasons "API-related path: $file"}
  if($file -match '(?i)(migration|schema|database|sql)'){Add-Unique $gates 'database-gate';Add-Unique $reasons "Data contract path: $file"}
}
$result=[ordered]@{schemaVersion=1;repositoryPath=$RepositoryPath;base=$Base;staged=$Staged.IsPresent;files=$files;impact=[ordered]@{confidence=if($files.Count){'HEURISTIC'}else{'NONE'};selectedPacks=@($packs);suggestedGates=@($gates);reasons=@($reasons)};limitations='Path-based analysis only; inspect imports, contracts, and tests before relying on it.'}
if($Json){$result|ConvertTo-Json -Depth 5}else{Write-Output "Diff impact: $($files.Count) files";Write-Output "Confidence: $($result.impact.confidence)";Write-Output "Limitations: $($result.limitations)";Write-Output "Packs: $($packs -join ', ')";Write-Output "Gates: $($gates -join ', ')"}
