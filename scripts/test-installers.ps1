$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ("ueef-install-test-" + [guid]::NewGuid().ToString('N'))

function Assert-Installed([string]$RuntimeRoot, [string]$Agent) {
  $target = Join-Path $RuntimeRoot $Agent
  foreach ($path in @('UEEF-LOADER.md','framework\01-core\00-core-system.md','scripts\ueef-status.ps1')) {
    if (!(Test-Path -LiteralPath (Join-Path $target $path))) { throw "Installer missing $Agent/$path" }
  }
  $state = Get-Content -LiteralPath (Join-Path $RuntimeRoot 'UEEF-ACTIVE.json') -Raw | ConvertFrom-Json
  if ($state.agent -ne $Agent) { throw "Installer state agent mismatch: $Agent" }
}

try {
  $codexHome = Join-Path $sandbox 'codex-home'
  & (Join-Path $root 'scripts\install-codex.ps1') -CodexHome $codexHome -Agent 'codex-test' -Force -NoBackup | Out-Null
  Assert-Installed (Join-Path $codexHome 'ueef') 'codex-test'

  $installRoot = Join-Path $sandbox 'other-runtimes'
  & (Join-Path $root 'scripts\install-cursor.ps1') -InstallRoot $installRoot -Agent 'cursor-test' -Force -NoBackup | Out-Null
  Assert-Installed $installRoot 'cursor-test'
  & (Join-Path $root 'scripts\install-generic.ps1') -InstallRoot $installRoot -Agent 'generic-test' -Force -NoBackup | Out-Null
  Assert-Installed $installRoot 'generic-test'

  $bashCommand = Get-Command bash -ErrorAction SilentlyContinue
  $bashPath = if (Test-Path 'C:\Program Files\Git\bin\bash.exe') { 'C:\Program Files\Git\bin\bash.exe' } elseif ($bashCommand -and $bashCommand.Source -notmatch '[\\/]System32[\\/]bash\.exe$') { $bashCommand.Source } else { '' }
  if ($bashPath) {
    $unixRoot = (Join-Path $sandbox 'unix-runtimes').Replace('\','/')
    $env:UEEF_INSTALL_ROOT = $unixRoot
    $unixInstaller = (Join-Path $root 'scripts\install-generic.sh').Replace('\','/')
    $unixOutput = @(& $bashPath $unixInstaller --agent unix-test --force --no-backup 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Unix generic installer failed: $($unixOutput -join ' ')" }
    Assert-Installed (Join-Path $sandbox 'unix-runtimes') 'unix-test'
    Remove-Item Env:UEEF_INSTALL_ROOT -ErrorAction SilentlyContinue
  }

  $unsafeRejected = $false
  try { & (Join-Path $root 'scripts\install-codex.ps1') -CodexHome $codexHome -Agent '..\escape' -Force -NoBackup | Out-Null } catch { $unsafeRejected = $true }
  if (!$unsafeRejected) { throw 'Installer accepted unsafe agent name.' }
  Write-Host 'Installer tests passed'
} finally {
  Remove-Item Env:UEEF_INSTALL_ROOT -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
