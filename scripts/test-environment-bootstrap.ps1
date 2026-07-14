$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ("ueef-bootstrap-test-" + [guid]::NewGuid().ToString('N'))
$previousCodexHome = $env:CODEX_HOME
$previousGlobalPath = $env:UEEF_GLOBAL_PATH

try {
  $codexHome = Join-Path $sandbox 'codex-home'
  $runtime = Join-Path $codexHome 'ueef\codex'
  New-Item -ItemType Directory -Path $runtime -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $runtime 'UEEF-LOADER.md') -Value '# test runtime' -Encoding utf8
  Set-Content -LiteralPath (Join-Path $codexHome 'AGENTS.md') -Value '# test rules' -Encoding utf8
  foreach ($skill in @('skill-installer','openai-docs','skill-creator')) {
    $skillPath = Join-Path $codexHome "skills\.system\$skill"
    New-Item -ItemType Directory -Path $skillPath -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $skillPath 'SKILL.md') -Value '# test skill' -Encoding utf8
  }

  Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue
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
      $unixOutput = @(& $bashPath './scripts/environment-bootstrap.sh' 2>&1)
      if ($LASTEXITCODE -ne 0 -or $unixOutput -notcontains 'Overall READY') { throw "Unix bootstrap rejected valid UEEF_GLOBAL_PATH '$globalPath': $($unixOutput -join ' ')" }
    }
  }
  Write-Host 'Environment bootstrap tests passed'
} finally {
  if ($null -eq $previousCodexHome) { Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue } else { $env:CODEX_HOME = $previousCodexHome }
  if ($null -eq $previousGlobalPath) { Remove-Item Env:UEEF_GLOBAL_PATH -ErrorAction SilentlyContinue } else { $env:UEEF_GLOBAL_PATH = $previousGlobalPath }
  if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
