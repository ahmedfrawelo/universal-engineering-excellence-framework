param(
  [string]$InstallRoot = $(if ($env:UEEF_INSTALL_ROOT) { $env:UEEF_INSTALL_ROOT } elseif ($env:CODEX_HOME) { Join-Path $env:CODEX_HOME "ueef" } else { Join-Path (Split-Path -Parent $PSScriptRoot) "ueef-runtime" }),
  [string]$Agent = "generic"
)
$ErrorActionPreference = "Stop"
$SourceRoot = Split-Path -Parent $PSScriptRoot
$Target = Join-Path $InstallRoot $Agent
$BackupRoot = Join-Path $InstallRoot "backups"
if (!(Test-Path -LiteralPath (Join-Path $SourceRoot "framework"))) { throw "framework directory not found" }
if (Test-Path -LiteralPath $Target) {
  $answer = Read-Host "Existing UEEF install found at $Target. Back up and replace? (y/N)"
  if ($answer -notin @("y","Y","yes","YES")) { Write-Host "Install cancelled."; exit 1 }
  New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
  Copy-Item -LiteralPath $Target -Destination (Join-Path $BackupRoot "$Agent-$(Get-Date -Format yyyyMMddHHmmss)") -Recurse -Force
  Remove-Item -LiteralPath $Target -Recurse -Force
}
New-Item -ItemType Directory -Path $Target -Force | Out-Null
Get-ChildItem -LiteralPath $SourceRoot -Force | Where-Object { $_.Name -ne ".git" } | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $Target -Recurse -Force }
$Loader = Join-Path $Target "UEEF-LOADER.md"
$loaderLines = @("# UEEF Loader", "", "
Activate UEEF before every non-trivial engineering task. Report only framework/01-core/00-boot-loader.md and framework/01-core/00-core-system.md under Loaded. Use framework/01-core/01-master-loader.md only to select relevant modules. Do not load the full framework unless the task is about UEEF audit, update, install, validation, or rebuild. Finish with compact UEEF Verification.
")
[System.IO.File]::WriteAllLines($Loader, $loaderLines, [System.Text.UTF8Encoding]::new($false))
& (Join-Path $Target "scripts\write-active-state.ps1") -RepositoryPath $Target -CodexHome (Split-Path -Parent $InstallRoot) -SourceRepositoryPath $SourceRoot | Out-Null
Write-Host "UEEF installed for $Agent at $Target"
Write-Host "Verify loader: $Loader"
