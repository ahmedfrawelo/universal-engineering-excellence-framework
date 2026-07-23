[CmdletBinding()]
param([string]$RepositoryPath=(Get-Location).Path,[string]$Base='HEAD',[switch]$Staged,[switch]$Json)
$ErrorActionPreference='Stop';if(!(Test-Path -LiteralPath (Join-Path $RepositoryPath '.git'))){throw "Not a Git repository: $RepositoryPath"}
$args=@('-C',$RepositoryPath,'diff','--name-only');if($Staged){$args+='--cached'}else{$args+=$Base};$files=@(& git @args|Where-Object{$_})
$gates=[Collections.Generic.List[string]]::new();$packs=[Collections.Generic.List[string]]::new();$reasons=[Collections.Generic.List[string]]::new();$owners=[Collections.Generic.List[string]]::new();$signals=[Collections.Generic.List[object]]::new()
function Add-Unique($list,[string]$value){if(!$list.Contains($value)){$list.Add($value)}}
foreach($file in $files){
  $owner=($file -split '[\\/]')[0];if($owner){Add-Unique $owners $owner}
  if($file -match '\.(tsx|jsx|css|scss|html)$'){Add-Unique $packs '14-ui';Add-Unique $packs '15-ux';Add-Unique $gates 'ui-gate';Add-Unique $gates 'accessibility-gate';Add-Unique $reasons "UI-related file: $file"}
  if($file -match '\.(ps1|sh|mjs|js)$'){Add-Unique $gates 'testing-gate';Add-Unique $gates 'code-quality-gate';Add-Unique $reasons "Executable script: $file"}
  if($file -match '(?i)(auth|security|credential|token)'){Add-Unique $gates 'security-gate';Add-Unique $reasons "Security-sensitive path: $file"}
  if($file -match '(?i)(api|controller|route)'){Add-Unique $packs '13-api';Add-Unique $gates 'api-gate';Add-Unique $reasons "API-related path: $file"}
  if($file -match '(?i)(migration|schema|database|sql)'){Add-Unique $gates 'database-gate';Add-Unique $reasons "Data contract path: $file"}
  if($file -match '^config/(capability-registry|assistant-adapters|team-policy-profiles)\.json$'){Add-Unique $packs '59-skill-invocation-protocol';Add-Unique $gates 'documentation-gate';Add-Unique $reasons "Governed capability contract: $file"}
  if($file -match '^(VERSION\.md|release-manifest\.json|CHANGELOG\.md|docs/releases/)'){Add-Unique $gates 'documentation-gate';Add-Unique $reasons "Release contract: $file"}
  $path=Join-Path $RepositoryPath $file;if(Test-Path -LiteralPath $path -PathType Leaf){$text=Get-Content -LiteralPath $path -Raw;if($text -match '(?m)\b(import|require)\b'){$signals.Add([pscustomobject]@{file=$file;kind='import-or-require';detail='Source contains an import/require signal; inspect dependency reachability.'})}}
}
$confidence=if(!$files.Count){'NONE'}elseif($signals.Count -or $owners.Count -gt 1){'MODERATE'}else{'HEURISTIC'}
$result=[ordered]@{schemaVersion=2;repositoryPath=$RepositoryPath;base=$Base;staged=$Staged.IsPresent;files=$files;impact=[ordered]@{confidence=$confidence;selectedPacks=@($packs);suggestedGates=@($gates);sharedOwners=@($owners);contractSignals=@($signals);reasons=@($reasons)};limitations='Heuristic local analysis: owners and import signals are textual, not a complete dependency graph; inspect imports, contracts, and tests before relying on it.'}
if($Json){$result|ConvertTo-Json -Depth 6}else{Write-Output "Diff impact: $($files.Count) files";Write-Output "Confidence: $($result.impact.confidence)";Write-Output "Limitations: $($result.limitations)";Write-Output "Owners: $($owners -join ', ')";Write-Output "Packs: $($packs -join ', ')";Write-Output "Gates: $($gates -join ', ')"}
