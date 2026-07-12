$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ("ueef-runtime-test-" + [guid]::NewGuid().ToString('N'))
$codexHome = Join-Path $sandbox 'codex-home'

try {
  $unsafeRejected = $false
  try { & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent '..\escape' | Out-Null }
  catch { $unsafeRejected = $true }
  if (!$unsafeRejected) { throw 'Unsafe agent path was accepted.' }
  if (Test-Path -LiteralPath (Join-Path $sandbox 'escape')) { throw 'Unsafe agent path wrote outside runtime root.' }

  & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent 'test-agent' | Out-Null
  $runtime = Join-Path $codexHome 'ueef\test-agent'
  $statePath = Join-Path $codexHome 'ueef\UEEF-ACTIVE.json'
  $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
  if ($state.agent -ne 'test-agent') { throw 'Active state did not preserve the agent name.' }
  if ([IO.Path]::GetFullPath([string]$state.runtimePath) -ne [IO.Path]::GetFullPath($runtime)) { throw 'Active state runtime path is wrong.' }
  $loader = Get-Content -LiteralPath (Join-Path $runtime 'UEEF-LOADER.md') -Raw
  foreach ($term in @('environment-bootstrap','Agent and model routing:','Loaded: boot-loader, core-system')) {
    if ($loader -notmatch [regex]::Escape($term)) { throw "Generated loader missing: $term" }
  }
  $agents = Get-Content -LiteralPath (Join-Path $codexHome 'AGENTS.md') -Raw
  foreach ($term in @('save-contract bugs','Repetition does not convert','external or user-only condition','no meaningful local work remains')) {
    if ($agents -notmatch [regex]::Escape($term)) { throw "Generated AGENTS missing delivery continuation contract: $term" }
  }
  $status = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef'))
  if ($status -notcontains 'Overall: ACTIVE') { throw 'Valid generated runtime did not become ACTIVE.' }
  $bashPath = if (Test-Path 'C:\Program Files\Git\bin\bash.exe') { 'C:\Program Files\Git\bin\bash.exe' } else { '' }
  if ($bashPath) {
    $shellStatus = @(& $bashPath (Join-Path $runtime 'scripts\ueef-status.sh').Replace('\','/') 2>&1)
    if ($LASTEXITCODE -ne 0 -or $shellStatus -notcontains 'Overall: ACTIVE') { throw "Unix status rejected valid runtime: $($shellStatus -join ' ')" }
  }

  $state.active = $false
  $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $statePath -Encoding utf8
  $invalidStatus = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef'))
  if ($invalidStatus -notcontains 'Overall: INACTIVE') { throw 'Malformed/inactive state was accepted.' }
  Write-Host 'Runtime hardening tests passed'
} finally {
  if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
