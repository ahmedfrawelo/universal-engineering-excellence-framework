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
  $statePath = Join-Path $installRoot 'UEEF-ACTIVE.json'
  $stateBeforeRollback = Get-Content -LiteralPath $statePath -Raw
  $installerRollbackTriggered = $false
  try { & (Join-Path $root 'scripts\install-runtime.ps1') -SourceRoot $root -InstallRoot $installRoot -Agent 'generic-test' -Force -NoBackup -TestFailAfterState | Out-Null }
  catch { $installerRollbackTriggered = $_.Exception.Message -like '*Injected test failure*' }
  if (!$installerRollbackTriggered) { throw 'Windows installer rollback injection did not fail.' }
  if ((Get-Content -LiteralPath $statePath -Raw) -cne $stateBeforeRollback) { throw 'Windows installer did not restore the previous active state.' }
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
    $unixStatePath = Join-Path $sandbox 'unix-runtimes\UEEF-ACTIVE.json'
    $unixStateBeforeRollback = Get-Content -LiteralPath $unixStatePath -Raw
    $unixRuntimeInstaller = (Join-Path $root 'scripts\install-runtime.sh').Replace('\','/')
    $unixSource = $root.Replace('\','/')
    $previousErrorAction = $ErrorActionPreference
    try {
      $ErrorActionPreference = 'Continue'
      $unixRollbackOutput = @(& $bashPath $unixRuntimeInstaller $unixSource $unixRoot unix-test 1 1 1 2>&1)
      $unixRollbackExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousErrorAction }
    if ($unixRollbackExit -eq 0) { throw 'Unix installer rollback injection did not fail.' }
    if ((Get-Content -LiteralPath $unixStatePath -Raw) -cne $unixStateBeforeRollback) { throw 'Unix installer did not restore the previous active state.' }
    Assert-Installed (Join-Path $sandbox 'unix-runtimes') 'unix-test'
    Remove-Item Env:UEEF_INSTALL_ROOT -ErrorAction SilentlyContinue
  }

  $unsafeRejected = $false
  try { & (Join-Path $root 'scripts\install-codex.ps1') -CodexHome $codexHome -Agent '..\escape' -Force -NoBackup | Out-Null } catch { $unsafeRejected = $true }
  if (!$unsafeRejected) { throw 'Installer accepted unsafe agent name.' }
  foreach ($installerName in @('install-design-engineering-skills.ps1','install-design-engineering-skills.sh')) {
    $installerText = Get-Content -LiteralPath (Join-Path $root "scripts\$installerName") -Raw
    if ($installerText -notmatch '--ref' -or $installerText -notmatch '\b[0-9a-f]{40}\b') {
      throw "$installerName does not pin the audited design-skill commit."
    }
  }
  $global:LASTEXITCODE = 0
  Write-Host 'Installer tests passed'
} finally {
  Remove-Item Env:UEEF_INSTALL_ROOT -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
