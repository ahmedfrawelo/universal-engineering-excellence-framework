param(
  [string]$SourcePath = (Split-Path -Parent $PSScriptRoot),
  [string]$RuntimePath = $(if ($env:CODEX_HOME) { Join-Path $env:CODEX_HOME "ueef\codex" } else { "E:\shared folder\codex-home\ueef\codex" })
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'runtime-file-policy.ps1')

$sourceRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourcePath).Path)
$runtimeRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $RuntimePath).Path)
$sourceFiles = @(Get-UeefReleaseRelativeFiles -SourcePath $sourceRoot)

$mismatches = @()
foreach ($file in $sourceFiles) {
  $sourceFile = Join-Path $sourceRoot $file
  $runtimeFile = Join-Path $runtimeRoot $file
  if (!(Test-Path -LiteralPath $runtimeFile)) { $mismatches += "Missing runtime: $file"; continue }
  $sourceHash = (Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash
  $runtimeHash = (Get-FileHash -LiteralPath $runtimeFile -Algorithm SHA256).Hash
  if ($sourceHash -ne $runtimeHash) { $mismatches += "Different: $file" }
}
foreach ($runtimeFile in Get-ChildItem -LiteralPath $runtimeRoot -Recurse -File -Force) {
  $relative = $runtimeFile.FullName.Substring($runtimeRoot.Length).TrimStart('\','/').Replace('\','/')
  if ($relative -eq 'UEEF-LOADER.md') { continue }
  if ($sourceFiles -notcontains $relative) { $mismatches += "Extra runtime: $relative" }
}

$oldHomePath = Join-Path $HOME ".ueef"
$oldHomeExists = Test-Path -LiteralPath $oldHomePath

Write-Output "UEEF Runtime Drift Check"
Write-Output "------------------------"
Write-Output "Source Path: $SourcePath"
Write-Output "Runtime Path: $RuntimePath"
Write-Output "Source files checked: $($sourceFiles.Count)"
$runtimeLoader = Join-Path $runtimeRoot 'UEEF-LOADER.md'
if (!(Test-Path -LiteralPath $runtimeLoader)) { $mismatches += 'Missing runtime: UEEF-LOADER.md' }
else {
  $loaderText = Get-Content -LiteralPath $runtimeLoader -Raw
  foreach ($term in @('Agent and model routing:','environment-bootstrap','Loaded: boot-loader, core-system')) {
    if ($loaderText -notmatch [regex]::Escape($term)) { $mismatches += "Runtime loader missing contract: $term" }
  }
}
Write-Output "Old HOME .ueef exists: $(if ($oldHomeExists) { 'YES' } else { 'NO' })"
if ($mismatches.Count) {
  Write-Output "Drift: YES"
  foreach ($m in $mismatches) { Write-Output "- $m" }
  Write-Output "Overall: DRIFT"
  exit 1
}
Write-Output "Drift: NO"
Write-Output "Overall: SYNCED"
