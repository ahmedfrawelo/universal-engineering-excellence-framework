param(
  [string]$SourcePath = (Split-Path -Parent $PSScriptRoot),
  [string]$RuntimePath = $(if ($env:CODEX_HOME) { Join-Path $env:CODEX_HOME "ueef\codex" } else { "E:\shared folder\codex-home\ueef\codex" })
)
$ErrorActionPreference = "Stop"

$criticalFiles = @(
  "README.md",
  "INSTALL.md",
  "scripts/ueef-status.ps1",
  "scripts/sync-runtime.ps1",
  "scripts/check-runtime-drift.ps1",
  "scripts/select-quality-gates.ps1",
  "scripts/write-active-state.ps1",
  "framework/01-core/00-core-system.md",
  "framework/01-core/01-master-loader.md",
  "framework/01-core/02-master-index.md",
  "framework/01-core/10-runtime-activation-proof.md",
  "framework/01-core/12-ueef-required-preflight.md",
  "framework/03-runtime/00-runtime-sequence.md",
  "framework/27-quality-gates/16-ueef-activation-gate.md"
)

$mismatches = @()
foreach ($file in $criticalFiles) {
  $sourceFile = Join-Path $SourcePath $file
  $runtimeFile = Join-Path $RuntimePath $file
  if (!(Test-Path -LiteralPath $sourceFile)) { $mismatches += "Missing source: $file"; continue }
  if (!(Test-Path -LiteralPath $runtimeFile)) { $mismatches += "Missing runtime: $file"; continue }
  $sourceHash = (Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash
  $runtimeHash = (Get-FileHash -LiteralPath $runtimeFile -Algorithm SHA256).Hash
  if ($sourceHash -ne $runtimeHash) { $mismatches += "Different: $file" }
}

$oldHomePath = Join-Path $HOME ".ueef"
$oldHomeExists = Test-Path -LiteralPath $oldHomePath

Write-Output "UEEF Runtime Drift Check"
Write-Output "------------------------"
Write-Output "Source Path: $SourcePath"
Write-Output "Runtime Path: $RuntimePath"
Write-Output "Critical files checked: $($criticalFiles.Count)"
Write-Output "Old HOME .ueef exists: $(if ($oldHomeExists) { 'YES' } else { 'NO' })"
if ($mismatches.Count) {
  Write-Output "Drift: YES"
  foreach ($m in $mismatches) { Write-Output "- $m" }
  Write-Output "Overall: DRIFT"
  exit 1
}
Write-Output "Drift: NO"
Write-Output "Overall: SYNCED"
