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
  $sentinel = Join-Path $runtime 'active-task-sentinel.txt'
  Set-Content -LiteralPath $sentinel -Value 'must survive a runtime update' -Encoding utf8
  & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent 'test-agent' | Out-Null
  if (!(Test-Path -LiteralPath $sentinel)) { throw 'Runtime sync removed active-task files instead of updating in place.' }
  $staleRuntimeFile = Join-Path $runtime 'framework\stale-runtime-file.md'
  Set-Content -LiteralPath $staleRuntimeFile -Value 'must be pruned from owned runtime folders' -Encoding utf8
  & (Join-Path $root 'scripts\check-runtime-drift.ps1') -SourcePath $root -RuntimePath $runtime | Out-Null
  $staleDetected = $LASTEXITCODE -ne 0
  if (!$staleDetected) { throw 'Runtime drift check accepted a stale file inside an owned runtime folder.' }
  & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent 'test-agent' | Out-Null
  if (Test-Path -LiteralPath $staleRuntimeFile) { throw 'Runtime sync left a stale file inside an owned runtime folder.' }
  if (!(Test-Path -LiteralPath $sentinel)) { throw 'Runtime sync pruned an active-task root file while removing stale owned files.' }
  $syncText = Get-Content -LiteralPath (Join-Path $root 'scripts\sync-runtime.ps1') -Raw
  if ($syncText -match [regex]::Escape('Remove-Item -LiteralPath $resolvedRuntime -Recurse -Force')) { throw 'Runtime sync can still delete the active runtime.' }
  $statePath = Join-Path $codexHome 'ueef\UEEF-ACTIVE.json'
  $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
  if ($state.agent -ne 'test-agent') { throw 'Active state did not preserve the agent name.' }
  if ([IO.Path]::GetFullPath([string]$state.runtimePath) -ne [IO.Path]::GetFullPath($runtime)) { throw 'Active state runtime path is wrong.' }
  $loader = Get-Content -LiteralPath (Join-Path $runtime 'UEEF-LOADER.md') -Raw
  foreach ($term in @('environment-bootstrap','Agent and model routing:','Loaded: boot-loader, core-system')) {
    if ($loader -notmatch [regex]::Escape($term)) { throw "Generated loader missing: $term" }
  }
  $agents = Get-Content -LiteralPath (Join-Path $codexHome 'AGENTS.md') -Raw
  foreach ($term in @('save-contract bugs','Repetition does not convert','external or user-only condition','no meaningful local work remains','When a goal is ACTIVE','read current goal status')) {
    if ($agents -notmatch [regex]::Escape($term)) { throw "Generated AGENTS missing delivery continuation contract: $term" }
  }
  $status = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef') -SkipRuntimeDrift)
  if ($status -notcontains 'Overall: ACTIVE') { throw 'Valid generated runtime did not become ACTIVE.' }
  Set-Content -LiteralPath (Join-Path $runtime 'README.md') -Value 'intentional runtime drift' -Encoding utf8
  $driftStatus = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef'))
  if ($driftStatus -notcontains 'Runtime drift: FAIL' -or $driftStatus -notcontains 'Overall: INACTIVE') { throw 'Runtime drift did not invalidate ACTIVE status.' }
  & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent 'test-agent' | Out-Null
  $statusAfterRepair = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef'))
  if ($statusAfterRepair -notcontains 'Runtime drift: PASS' -or $statusAfterRepair -notcontains 'Overall: ACTIVE') { throw 'Runtime resync did not repair drift status.' }
  $bashPath = if (Test-Path 'C:\Program Files\Git\bin\bash.exe') { 'C:\Program Files\Git\bin\bash.exe' } else { '' }
  if ($bashPath) {
    $shellStatus = @(& $bashPath (Join-Path $runtime 'scripts\ueef-status.sh').Replace('\','/') 2>&1)
    if ($LASTEXITCODE -ne 0 -or $shellStatus -notcontains 'Overall: ACTIVE') { throw "Unix status rejected valid runtime: $($shellStatus -join ' ')" }
  }

  $state.active = $false
  $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $statePath -Encoding utf8
  $invalidStatus = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef') -SkipRuntimeDrift)
  if ($invalidStatus -notcontains 'Overall: INACTIVE') { throw 'Malformed/inactive state was accepted.' }
  Write-Host 'Runtime hardening tests passed'
} finally {
  if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
