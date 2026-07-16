param(
  [string]$SourcePath = (Split-Path -Parent $PSScriptRoot),
  [string]$RuntimePath = $(if ($env:CODEX_HOME) { Join-Path $env:CODEX_HOME "ueef\codex" } else { "E:\shared folder\codex-home\ueef\codex" })
)
$ErrorActionPreference = "Stop"

$sourceRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourcePath).Path)
$runtimeRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $RuntimePath).Path)
$sourceFiles = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Force | Where-Object {
  $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.Name -ne 'UEEF-LOADER.md'
})
$ownedRuntimeDirs = @('framework','scripts','docs','examples','tools','assets')

$mismatches = @()
foreach ($sourceFile in $sourceFiles) {
  $file = $sourceFile.FullName.Substring($sourceRoot.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  $runtimeFile = Join-Path $runtimeRoot $file
  if (!(Test-Path -LiteralPath $runtimeFile)) { $mismatches += "Missing runtime: $file"; continue }
  $sourceHash = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash
  $runtimeHash = (Get-FileHash -LiteralPath $runtimeFile -Algorithm SHA256).Hash
  if ($sourceHash -ne $runtimeHash) { $mismatches += "Different: $file" }
}
foreach ($ownedDir in $ownedRuntimeDirs) {
  $sourceOwnedDir = Join-Path $sourceRoot $ownedDir
  $runtimeOwnedDir = Join-Path $runtimeRoot $ownedDir
  if (!(Test-Path -LiteralPath $runtimeOwnedDir)) { continue }
  $runtimeFiles = @(Get-ChildItem -LiteralPath $runtimeOwnedDir -Recurse -File -Force)
  foreach ($runtimeFile in $runtimeFiles) {
    $relativeOwnedPath = $runtimeFile.FullName.Substring($runtimeOwnedDir.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $sourceEquivalent = Join-Path $sourceOwnedDir $relativeOwnedPath
    if (!(Test-Path -LiteralPath $sourceEquivalent)) { $mismatches += "Extra runtime: $ownedDir/$relativeOwnedPath" }
  }
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
