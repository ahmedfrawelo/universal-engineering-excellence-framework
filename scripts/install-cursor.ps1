param(
  [string]$InstallRoot = $(if ($env:UEEF_INSTALL_ROOT) { $env:UEEF_INSTALL_ROOT } elseif ($env:CODEX_HOME) { Join-Path $env:CODEX_HOME 'ueef' } else { Join-Path (Split-Path -Parent $PSScriptRoot) 'ueef-runtime' }),
  [string]$Agent = 'cursor',
  [switch]$Force,
  [switch]$NoBackup
)
& (Join-Path $PSScriptRoot 'install-runtime.ps1') -SourceRoot (Split-Path -Parent $PSScriptRoot) -InstallRoot $InstallRoot -Agent $Agent -Force:$Force -NoBackup:$NoBackup
