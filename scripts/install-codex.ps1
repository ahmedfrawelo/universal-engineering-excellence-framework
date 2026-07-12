param(
  [string]$CodexHome = $env:CODEX_HOME,
  [string]$Agent = "codex",
  [switch]$Force,
  [switch]$NoBackup
)
$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($CodexHome)) {
  throw "CODEX_HOME is required for exact Codex installation. Run inside Codex or pass -CodexHome explicitly."
}
if ($NoBackup -and !$Force) { throw "-NoBackup requires -Force." }
if ($Agent -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$' -or $Agent -in @('.', '..')) {
  throw "Unsafe agent name. Use one leaf name containing letters, numbers, dot, underscore, or hyphen."
}
$SourceRoot = Split-Path -Parent $PSScriptRoot
$resolvedSource = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null
$resolvedCodexHome = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $CodexHome).Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
$RuntimeRoot = [IO.Path]::GetFullPath((Join-Path $resolvedCodexHome "ueef")).TrimEnd([IO.Path]::DirectorySeparatorChar)
$Target = [IO.Path]::GetFullPath((Join-Path $RuntimeRoot $Agent)).TrimEnd([IO.Path]::DirectorySeparatorChar)
$BackupRoot = Join-Path $RuntimeRoot "backups"
if (!(Test-Path -LiteralPath (Join-Path $SourceRoot "framework"))) { throw "framework directory not found" }
if (!(Test-Path -LiteralPath (Join-Path $SourceRoot "scripts\sync-runtime.ps1"))) { throw "scripts\sync-runtime.ps1 not found" }
if ((Split-Path -Parent $Target) -ne $RuntimeRoot) { throw "Refusing unsafe runtime target: $Target" }
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
}
& (Join-Path $SourceRoot "scripts\sync-runtime.ps1") -SourcePath $SourceRoot -CodexHome $resolvedCodexHome -Agent $Agent
Write-Host "UEEF Codex runtime installed exactly from repository source."
Write-Host "Runtime: $Target"
Write-Host "Codex AGENTS: $(Join-Path $CodexHome 'AGENTS.md')"
Write-Host "Active state: $(Join-Path $RuntimeRoot 'UEEF-ACTIVE.json')"
