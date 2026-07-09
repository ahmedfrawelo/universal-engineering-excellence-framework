param(
  [string]$InstallRoot = "$HOME\.ueef",
  [string]$Agent = "generic"
)
$ErrorActionPreference = "Stop"
$SourceRoot = Split-Path -Parent $PSScriptRoot
$Target = Join-Path $InstallRoot $Agent
$BackupRoot = Join-Path $InstallRoot "backups"
if (!(Test-Path (Join-Path $SourceRoot "framework"))) { throw "framework directory not found" }
if (Test-Path $Target) {
  $answer = Read-Host "Existing UEEF install found at $Target. Back up and replace? (y/N)"
  if ($answer -notin @("y","Y","yes","YES")) { Write-Host "Install cancelled."; exit 1 }
  New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
  Copy-Item -LiteralPath $Target -Destination (Join-Path $BackupRoot "$Agent-$(Get-Date -Format yyyyMMddHHmmss)") -Recurse -Force
}
New-Item -ItemType Directory -Path $Target -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $SourceRoot "framework") -Destination $Target -Recurse -Force
$Loader = Join-Path $Target "UEEF-LOADER.md"
@"
# UEEF Loader

Load UEEF before every engineering task. Start with framework/01-core/01-master-loader.md and framework/MASTER_INDEX.md. Inspect the project, detect stack and architecture, detect tools and skills, plan before editing, avoid duplication, prioritize security and performance, run quality gates, and finish with evidence.
"@ | Set-Content -LiteralPath $Loader -Encoding utf8
Write-Host "UEEF installed for $Agent at $Target"
Write-Host "Verify loader: $Loader"
