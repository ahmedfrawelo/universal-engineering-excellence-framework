$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ("ueef-runtime-test-" + [guid]::NewGuid().ToString('N'))
$codexHome = Join-Path $sandbox 'codex-home'

try {
  . (Join-Path $root 'scripts\runtime-file-policy.ps1')
  $unsafeRejected = $false
  try { & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent '..\escape' | Out-Null }
  catch { $unsafeRejected = $true }
  if (!$unsafeRejected) { throw 'Unsafe agent path was accepted.' }
  if (Test-Path -LiteralPath (Join-Path $sandbox 'escape')) { throw 'Unsafe agent path wrote outside runtime root.' }

  $overlapSource = Join-Path $sandbox 'overlap-source'
  New-Item -ItemType Directory -Path (Join-Path $overlapSource 'framework') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $overlapSource 'VERSION.md') -Value 'version: 0.0.0.'
  $overlapRejected = $false
  try { & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $overlapSource -CodexHome (Join-Path $overlapSource 'codex-home') -Agent 'test-agent' | Out-Null } catch { $overlapRejected = $_.Exception.Message -like '*overlapping source and CODEX_HOME*' }
  if (!$overlapRejected) { throw 'Runtime sync accepted CODEX_HOME inside the source tree.' }

  $sensitiveSource = Join-Path $sandbox 'sensitive-source'
  New-Item -ItemType Directory -Path (Join-Path $sensitiveSource 'docs') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $sensitiveSource 'docs\.env.production') -Value 'SECRET=value'
  $sensitiveRejected = $false
  try { Get-UeefReleaseRelativeFiles -SourcePath $sensitiveSource | Out-Null } catch { $sensitiveRejected = $_.Exception.Message -like '*Sensitive file*' }
  if (!$sensitiveRejected) { throw 'Runtime file policy accepted a sensitive environment file.' }

  $policySource = Join-Path $sandbox 'policy-source'
  New-Item -ItemType Directory -Path (Join-Path $policySource 'docs') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $policySource 'README.md') -Value '# fixture'
  Set-Content -LiteralPath (Join-Path $policySource 'docs\guide.md') -Value '# guide'
  $nonEmptyDestination = Join-Path $sandbox 'non-empty-destination'
  New-Item -ItemType Directory -Path $nonEmptyDestination | Out-Null
  Set-Content -LiteralPath (Join-Path $nonEmptyDestination 'sentinel.txt') -Value 'preserve'
  $nonEmptyRejected = $false
  try { Copy-UeefReleaseFiles -SourcePath $policySource -DestinationPath $nonEmptyDestination } catch { $nonEmptyRejected = $_.Exception.Message -like '*must be empty*' }
  if (!$nonEmptyRejected) { throw 'Windows release copier accepted a non-empty destination.' }
  $overlapCopyRejected = $false
  try { Copy-UeefReleaseFiles -SourcePath $policySource -DestinationPath (Join-Path $policySource 'runtime') } catch { $overlapCopyRejected = $_.Exception.Message -like '*overlapping release destination*' }
  if (!$overlapCopyRejected) { throw 'Windows release copier accepted a destination inside its source.' }
  $previousErrorAction = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $nodeNonEmpty = & node (Join-Path $root 'scripts\copy-release-files.mjs') $policySource $nonEmptyDestination --include-loader 2>&1 | Out-String
    $nodeNonEmptyExit = $LASTEXITCODE
    $nodeOverlap = & node (Join-Path $root 'scripts\copy-release-files.mjs') $policySource (Join-Path $policySource 'runtime') --include-loader 2>&1 | Out-String
    $nodeOverlapExit = $LASTEXITCODE
  } finally { $ErrorActionPreference = $previousErrorAction }
  if ($nodeNonEmptyExit -eq 0 -or $nodeNonEmpty -notlike '*must be empty*') { throw 'Portable release copier accepted a non-empty destination.' }
  if ($nodeOverlapExit -eq 0 -or $nodeOverlap -notlike '*overlapping release destination*') { throw 'Portable release copier accepted a destination inside its source.' }

  New-Item -ItemType Directory -Path $codexHome -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $codexHome 'AGENTS.md') -Value "# User rules`n`nKeep this custom rule." -Encoding utf8
  & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent 'test-agent' | Out-Null
  $runtime = Join-Path $codexHome 'ueef\test-agent'
  $sentinel = Join-Path $runtime 'active-task-sentinel.txt'
  Set-Content -LiteralPath $sentinel -Value 'must be removed because it is not part of the release' -Encoding utf8
  & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent 'test-agent' | Out-Null
  if (Test-Path -LiteralPath $sentinel) { throw 'Runtime sync retained an unowned root file.' }
  $staleRuntimeFile = Join-Path $runtime 'framework\stale-runtime-file.md'
  Set-Content -LiteralPath $staleRuntimeFile -Value 'must be pruned from owned runtime folders' -Encoding utf8
  & (Join-Path $root 'scripts\check-runtime-drift.ps1') -SourcePath $root -RuntimePath $runtime | Out-Null
  $staleDetected = $LASTEXITCODE -ne 0
  if (!$staleDetected) { throw 'Runtime drift check accepted a stale file inside an owned runtime folder.' }
  & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent 'test-agent' | Out-Null
  if (Test-Path -LiteralPath $staleRuntimeFile) { throw 'Runtime sync left a stale file inside an owned runtime folder.' }
  $syncText = Get-Content -LiteralPath (Join-Path $root 'scripts\sync-runtime.ps1') -Raw
  foreach ($term in @('stagingPath','rollbackPath','Copy-UeefReleaseFiles','validate-framework.ps1')) {
    if ($syncText -notmatch [regex]::Escape($term)) { throw "Runtime sync is missing transactional control: $term" }
  }
  $statePath = Join-Path $codexHome 'ueef\UEEF-ACTIVE.json'
  $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
  if ($state.agent -ne 'test-agent') { throw 'Active state did not preserve the agent name.' }
  if ([IO.Path]::GetFullPath([string]$state.runtimePath) -ne [IO.Path]::GetFullPath($runtime)) { throw 'Active state runtime path is wrong.' }
  $loader = Get-Content -LiteralPath (Join-Path $runtime 'UEEF-LOADER.md') -Raw
  foreach ($term in @('environment-bootstrap','Agent and model routing:','Loaded: boot-loader, core-system')) {
    if ($loader -notmatch [regex]::Escape($term)) { throw "Generated loader missing: $term" }
  }
  $agents = Get-Content -LiteralPath (Join-Path $codexHome 'AGENTS.md') -Raw
  foreach ($term in @('# User rules','Keep this custom rule.','<!-- UEEF-MANAGED:START -->','<!-- UEEF-MANAGED:END -->')) {
    if ($agents -notmatch [regex]::Escape($term)) { throw "Runtime sync did not preserve managed AGENTS content: $term" }
  }
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
    $decoyLoader = Join-Path $codexHome 'ueef\backups\decoy\UEEF-LOADER.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $decoyLoader) -Force | Out-Null
    Set-Content -LiteralPath $decoyLoader -Value '# decoy'
    $runtimeLoader = Join-Path $runtime 'UEEF-LOADER.md'
    $heldLoader = Join-Path $codexHome 'held-loader.md'
    Move-Item -LiteralPath $runtimeLoader -Destination $heldLoader
    try {
      $missingLoaderStatus = @(& $bashPath (Join-Path $runtime 'scripts\ueef-status.sh').Replace('\','/') 2>&1)
      if ($missingLoaderStatus -notcontains 'Global loader: FAIL' -or $missingLoaderStatus -notcontains 'Overall: INACTIVE') { throw 'Unix status accepted a loader found only in backups.' }
    } finally { Move-Item -LiteralPath $heldLoader -Destination $runtimeLoader }
  }

  $state.active = $false
  $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $statePath -Encoding utf8
  $invalidStatus = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef') -SkipRuntimeDrift)
  if ($invalidStatus -notcontains 'Overall: INACTIVE') { throw 'Malformed/inactive state was accepted.' }
  Write-Host 'Runtime hardening tests passed'
} finally {
  if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
