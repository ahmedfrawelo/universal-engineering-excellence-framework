param(
  [string]$SourcePath = (Split-Path -Parent $PSScriptRoot),
  [string]$RuntimePath = ''
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'resolve-codex-home.ps1')
if ([string]::IsNullOrWhiteSpace($RuntimePath)) { $RuntimePath = Resolve-UeefCodexRuntimePath }
. (Join-Path $PSScriptRoot 'runtime-file-policy.ps1')

$sourceRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourcePath).Path)
$runtimeRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $RuntimePath).Path)
$sourceFiles = @(Get-UeefReleaseRelativeFiles -SourcePath $sourceRoot)
$expectedLoaderHash = ''
$statePath = Join-Path (Split-Path -Parent $runtimeRoot) 'UEEF-ACTIVE.json'
if (Test-Path -LiteralPath $statePath -PathType Leaf) {
  try {
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    if ([IO.Path]::GetFullPath([string]$state.runtimePath) -eq $runtimeRoot) { $expectedLoaderHash = [string]$state.runtimeLoaderSha256 }
  } catch { $expectedLoaderHash = '' }
}
$mismatches = @(Get-UeefRuntimeDriftMismatches -SourcePath $sourceRoot -RuntimePath $runtimeRoot -ExpectedLoaderHash $expectedLoaderHash)

$oldHomePath = Join-Path $HOME ".ueef"
$oldHomeExists = Test-Path -LiteralPath $oldHomePath

Write-Output "UEEF Runtime Drift Check"
Write-Output "------------------------"
Write-Output "Source Path: $SourcePath"
Write-Output "Runtime Path: $RuntimePath"
Write-Output "Source files checked: $($sourceFiles.Count)"
Write-Output "Old HOME .ueef exists: $(if ($oldHomeExists) { 'YES' } else { 'NO' })"
if ($mismatches.Count) {
  Write-Output "Drift: YES"
  foreach ($m in $mismatches) { Write-Output "- $m" }
  Write-Output "Overall: DRIFT"
  exit 1
}
Write-Output "Drift: NO"
Write-Output "Overall: SYNCED"
