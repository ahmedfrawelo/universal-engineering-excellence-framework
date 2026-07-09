param(
  [string]$CodexHome = $env:CODEX_HOME,
  [string]$Agent = "codex"
)
$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($CodexHome)) {
  throw "CODEX_HOME is required for exact Codex installation. Run inside Codex or pass -CodexHome explicitly."
}
$SourceRoot = Split-Path -Parent $PSScriptRoot
$RuntimeRoot = Join-Path $CodexHome "ueef"
$Target = Join-Path $RuntimeRoot $Agent
$BackupRoot = Join-Path $RuntimeRoot "backups"
if (!(Test-Path -LiteralPath (Join-Path $SourceRoot "framework"))) { throw "framework directory not found" }
if (!(Test-Path -LiteralPath (Join-Path $SourceRoot "scripts\sync-runtime.ps1"))) { throw "scripts\sync-runtime.ps1 not found" }
if (Test-Path -LiteralPath $Target) {
  $answer = Read-Host "Existing UEEF install found at $Target. Back up and replace? (y/N)"
  if ($answer -notin @("y","Y","yes","YES")) { Write-Host "Install cancelled."; exit 1 }
  New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
  Copy-Item -LiteralPath $Target -Destination (Join-Path $BackupRoot "$Agent-$(Get-Date -Format yyyyMMddHHmmss)") -Recurse -Force
}
& (Join-Path $SourceRoot "scripts\sync-runtime.ps1") -SourcePath $SourceRoot -CodexHome $CodexHome -Agent $Agent
Write-Host "UEEF Codex runtime installed exactly from repository source."
Write-Host "Runtime: $Target"
Write-Host "Codex AGENTS: $(Join-Path $CodexHome 'AGENTS.md')"
Write-Host "Active state: $(Join-Path $RuntimeRoot 'UEEF-ACTIVE.json')"
