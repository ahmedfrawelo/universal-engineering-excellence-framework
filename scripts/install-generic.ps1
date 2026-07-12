param(
  [string]$InstallRoot = $(if ($env:UEEF_INSTALL_ROOT) { $env:UEEF_INSTALL_ROOT } elseif ($env:CODEX_HOME) { Join-Path $env:CODEX_HOME "ueef" } else { Join-Path (Split-Path -Parent $PSScriptRoot) "ueef-runtime" }),
  [string]$Agent = "generic",
  [switch]$Force,
  [switch]$NoBackup
)
$ErrorActionPreference = "Stop"
if ($NoBackup -and !$Force) { throw "-NoBackup requires -Force." }
if ($Agent -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$' -or $Agent -in @('.', '..')) {
  throw "Unsafe agent name. Use one leaf name containing letters, numbers, dot, underscore, or hyphen."
}
$SourceRoot = Split-Path -Parent $PSScriptRoot
$resolvedSource = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
$resolvedInstallRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InstallRoot).Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
$Target = [IO.Path]::GetFullPath((Join-Path $resolvedInstallRoot $Agent)).TrimEnd([IO.Path]::DirectorySeparatorChar)
$BackupRoot = Join-Path $resolvedInstallRoot "backups"
if (!(Test-Path -LiteralPath (Join-Path $SourceRoot "framework"))) { throw "framework directory not found" }
if ((Split-Path -Parent $Target) -ne $resolvedInstallRoot) { throw "Refusing unsafe runtime target: $Target" }
if ($resolvedSource -eq $Target) {
  Write-Host "UEEF is already running from $Target; install is a no-op."
  exit 0
}
if ($Target.StartsWith($resolvedSource + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
    $resolvedSource.StartsWith($Target + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
  throw "Refusing overlapping source and target paths: $resolvedSource -> $Target"
}
if (Test-Path -LiteralPath $Target) {
  if (!$Force) { throw "Existing UEEF install found at $Target. Re-run with -Force to replace it." }
  if (!$NoBackup) {
    New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
    Copy-Item -LiteralPath $Target -Destination (Join-Path $BackupRoot "$Agent-$(Get-Date -Format yyyyMMddHHmmssfff)") -Recurse -Force
  }
  Remove-Item -LiteralPath $Target -Recurse -Force
}
New-Item -ItemType Directory -Path $Target -Force | Out-Null
Get-ChildItem -LiteralPath $SourceRoot -Force | Where-Object { $_.Name -ne ".git" } | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $Target -Recurse -Force }
$Loader = Join-Path $Target "UEEF-LOADER.md"
& (Join-Path $Target "scripts\write-active-state.ps1") -RepositoryPath $Target -CodexHome (Split-Path -Parent $resolvedInstallRoot) -RuntimeRoot $resolvedInstallRoot -Agent $Agent -SourceRepositoryPath $resolvedSource | Out-Null
Write-Host "UEEF installed for $Agent at $Target"
Write-Host "Verify loader: $Loader"
