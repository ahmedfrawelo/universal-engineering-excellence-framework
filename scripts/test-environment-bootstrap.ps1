$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ("ueef-bootstrap-test-" + [guid]::NewGuid().ToString('N'))
$previousCodexHome = $env:CODEX_HOME
$previousGlobalPath = $env:UEEF_GLOBAL_PATH
$previousRuntimeOverall = $env:UEEF_TEST_RUNTIME_OVERALL

try {
  $codexHome = Join-Path $sandbox 'codex-home'
  $runtime = Join-Path $codexHome 'ueef\codex'
  New-Item -ItemType Directory -Path $runtime,(Join-Path $runtime 'scripts') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $runtime 'UEEF-LOADER.md') -Value '# test runtime' -Encoding utf8
  @'
param(
  [string]$RepositoryPath,
  [string]$GlobalPath,
  [switch]$Json
)
$overall = if ($env:UEEF_TEST_RUNTIME_OVERALL) { $env:UEEF_TEST_RUNTIME_OVERALL } else { 'INACTIVE' }
[pscustomobject]@{ overall=$overall } | ConvertTo-Json
'@ | Set-Content -LiteralPath (Join-Path $runtime 'scripts\ueef-status.ps1') -Encoding utf8
  $unixStatus = @'
#!/usr/bin/env sh
printf 'Overall: %s\n' "${UEEF_TEST_RUNTIME_OVERALL:-INACTIVE}"
'@ -replace "`r`n","`n"
  [IO.File]::WriteAllText((Join-Path $runtime 'scripts\ueef-status.sh'), $unixStatus, [Text.UTF8Encoding]::new($false))
  Set-Content -LiteralPath (Join-Path $codexHome 'AGENTS.md') -Value '# test rules' -Encoding utf8
  foreach ($skill in @('skill-installer','openai-docs','skill-creator')) {
    $skillPath = Join-Path $codexHome "skills\.system\$skill"
    New-Item -ItemType Directory -Path $skillPath -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $skillPath 'SKILL.md') -Value '# test skill' -Encoding utf8
  }

  Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue
  $env:UEEF_TEST_RUNTIME_OVERALL = 'ACTIVE'
  foreach ($globalPath in @($runtime, (Split-Path -Parent $runtime))) {
    $env:UEEF_GLOBAL_PATH = $globalPath
    $output = (& (Join-Path $root 'scripts\environment-bootstrap.ps1') -Profile Core,AI 2>&1 | Out-String)
    if ($output -notmatch 'Overall READY') { throw "Bootstrap rejected valid UEEF_GLOBAL_PATH '$globalPath': $output" }
    if ($output -match 'UEEF Runtime.*MISSING|Runtime Loader.*MISSING') { throw "Bootstrap reported a false missing runtime for '$globalPath': $output" }
  }

  $bashPath = if (Test-Path 'C:\Program Files\Git\bin\bash.exe') { 'C:\Program Files\Git\bin\bash.exe' } else { '' }
  if ($bashPath) {
    foreach ($globalPath in @($runtime, (Split-Path -Parent $runtime))) {
      $env:UEEF_GLOBAL_PATH = $globalPath
      $env:UEEF_PROFILES = 'Core,AI'
      $unixScript = (Join-Path $root 'scripts\environment-bootstrap.sh').Replace('\','/')
      $unixOutput = @(& $bashPath $unixScript 2>&1)
      if ($LASTEXITCODE -ne 0 -or $unixOutput -notcontains 'Overall READY') { throw "Unix bootstrap rejected valid UEEF_GLOBAL_PATH '$globalPath': $($unixOutput -join ' ')" }
    }
  }

  $env:UEEF_TEST_RUNTIME_OVERALL = 'INACTIVE'
  $env:UEEF_GLOBAL_PATH = $runtime
  $powershell = (Get-Command powershell -ErrorAction Stop).Source
  $blockedOutput = (& $powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts\environment-bootstrap.ps1') -Profile Core,AI 2>&1 | Out-String)
  if ($LASTEXITCODE -ne 2 -or $blockedOutput -notmatch 'UEEF Runtime\s+Mandatory\s+INACTIVE' -or $blockedOutput -notmatch 'Overall BLOCKED') {
    throw "Windows bootstrap did not block an INACTIVE runtime: $blockedOutput"
  }

  if ($bashPath) {
    $env:UEEF_PROFILES = 'Core,AI'
    $unixScript = (Join-Path $root 'scripts\environment-bootstrap.sh').Replace('\','/')
    $blockedUnixOutput = @(& $bashPath $unixScript 2>&1)
    if ($LASTEXITCODE -ne 2 -or $blockedUnixOutput -contains 'UEEF Runtime PASS' -or $blockedUnixOutput -notcontains 'Overall BLOCKED') {
      throw "Unix bootstrap did not block an INACTIVE runtime: $($blockedUnixOutput -join ' ')"
    }
  }
  $global:LASTEXITCODE = 0
  Write-Host 'Environment bootstrap tests passed'
} finally {
  if ($null -eq $previousCodexHome) { Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue } else { $env:CODEX_HOME = $previousCodexHome }
  if ($null -eq $previousGlobalPath) { Remove-Item Env:UEEF_GLOBAL_PATH -ErrorAction SilentlyContinue } else { $env:UEEF_GLOBAL_PATH = $previousGlobalPath }
  if ($null -eq $previousRuntimeOverall) { Remove-Item Env:UEEF_TEST_RUNTIME_OVERALL -ErrorAction SilentlyContinue } else { $env:UEEF_TEST_RUNTIME_OVERALL = $previousRuntimeOverall }
  if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
