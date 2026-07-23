$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ("ueef-runtime-test-" + [guid]::NewGuid().ToString('N'))
$codexHome = Join-Path $sandbox 'codex-home'

function Initialize-FakeSkillInstaller([string]$TargetHome) {
  $installer = Join-Path $TargetHome 'skills\.system\skill-installer\scripts\install-skill-from-github.py'
  New-Item -ItemType Directory -Path (Split-Path -Parent $installer) -Force | Out-Null
  Set-Content -LiteralPath $installer -Encoding utf8 -Value @'
import pathlib
import sys
destination = pathlib.Path(sys.argv[sys.argv.index("--dest") + 1])
paths = sys.argv[sys.argv.index("--path") + 1:sys.argv.index("--dest")]
for path in paths:
    target = destination / pathlib.PurePosixPath(path).name
    target.mkdir(parents=True, exist_ok=True)
    (target / "SKILL.md").write_text("# test skill\n", encoding="utf-8")
'@
}

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

  New-Item -ItemType Directory -Path (Join-Path $policySource 'Framework') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $policySource 'Framework\wrong-case.md') -Value '# must not ship'
  & git -C $policySource init --quiet
  & git -C $policySource add README.md docs/guide.md Framework/wrong-case.md
  Set-Content -LiteralPath (Join-Path $policySource 'docs\untracked.md') -Value '# must not ship'
  $windowsTrackedDestination = Join-Path $sandbox 'windows-tracked-destination'
  Copy-UeefReleaseFiles -SourcePath $policySource -DestinationPath $windowsTrackedDestination
  if (Test-Path -LiteralPath (Join-Path $windowsTrackedDestination 'docs\untracked.md')) { throw 'Windows release policy copied an untracked file.' }
  if (Test-Path -LiteralPath (Join-Path $windowsTrackedDestination 'Framework\wrong-case.md')) { throw 'Windows release policy accepted a wrong-case owned directory.' }
  $nodeTrackedDestination = Join-Path $sandbox 'node-tracked-destination'
  & node (Join-Path $root 'scripts\copy-release-files.mjs') $policySource $nodeTrackedDestination | Out-Null
  if ($LASTEXITCODE -ne 0 -or (Test-Path -LiteralPath (Join-Path $nodeTrackedDestination 'docs\untracked.md'))) { throw 'Portable release policy copied an untracked file.' }
  if (Test-Path -LiteralPath (Join-Path $nodeTrackedDestination 'Framework\wrong-case.md')) { throw 'Portable release policy accepted a wrong-case owned directory.' }

  $outsideDocs = Join-Path $sandbox 'outside-docs'
  $junctionSource = Join-Path $sandbox 'junction-source'
  New-Item -ItemType Directory -Path $outsideDocs -Force | Out-Null
  New-Item -ItemType Directory -Path $junctionSource -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $outsideDocs 'external.md') -Value '# external'
  Set-Content -LiteralPath (Join-Path $junctionSource 'README.md') -Value '# fixture'
  New-Item -ItemType Junction -Path (Join-Path $junctionSource 'docs') -Target $outsideDocs | Out-Null
  $windowsJunctionRejected = $false
  try { Get-UeefReleaseRelativeFiles -SourcePath $junctionSource | Out-Null } catch { $windowsJunctionRejected = $_.Exception.Message -like '*Reparse-point*' }
  if (!$windowsJunctionRejected) { throw 'Windows release policy followed a reparse-point parent.' }
  $previousErrorAction = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $nodeJunctionOutput = & node (Join-Path $root 'scripts\copy-release-files.mjs') $junctionSource (Join-Path $sandbox 'node-junction-destination') 2>&1 | Out-String
    $nodeJunctionExit = $LASTEXITCODE
  } finally { $ErrorActionPreference = $previousErrorAction }
  if ($nodeJunctionExit -eq 0 -or $nodeJunctionOutput -notlike '*symbolic link*') { throw 'Portable release policy followed a linked parent.' }

  New-Item -ItemType Directory -Path $codexHome -Force | Out-Null
  Initialize-FakeSkillInstaller $codexHome
  Set-Content -LiteralPath (Join-Path $codexHome 'AGENTS.md') -Value "# User rules`n`nKeep this custom rule." -Encoding utf8
  & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent 'test-agent' | Out-Null
  $runtime = Join-Path $codexHome 'ueef\test-agent'
  $runtimeRoot = Join-Path $codexHome 'ueef'
  $staleTransaction = Join-Path $runtimeRoot '.sdeadbeef'
  $nonTransaction = Join-Path $runtimeRoot '.snot-a-transaction'
  New-Item -ItemType Directory -Path $staleTransaction,$nonTransaction | Out-Null
  (Get-Item -LiteralPath $staleTransaction).LastWriteTime = (Get-Date).AddMinutes(-11)
  & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent 'test-agent' | Out-Null
  if (Test-Path -LiteralPath $staleTransaction) { throw 'Runtime sync retained a stale transaction directory.' }
  if (!(Test-Path -LiteralPath $nonTransaction)) { throw 'Runtime sync removed a non-transaction directory.' }
  Remove-Item -LiteralPath $nonTransaction -Recurse -Force
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
  $runtimeLinkTarget = Join-Path $sandbox 'runtime-link-target'
  $runtimeLink = Join-Path $runtime 'framework\runtime-link'
  New-Item -ItemType Directory -Path $runtimeLinkTarget -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $runtimeLinkTarget 'external.md') -Value '# external runtime content'
  New-Item -ItemType Junction -Path $runtimeLink -Target $runtimeLinkTarget | Out-Null
  try {
    $runtimeLinkMismatches = @(Get-UeefRuntimeDriftMismatches -SourcePath $root -RuntimePath $runtime)
    if (!($runtimeLinkMismatches | Where-Object { $_ -like 'Unsafe runtime reparse point:*' })) { throw 'Runtime drift accepted a reparse point inside the runtime.' }
  } finally { if (Test-Path -LiteralPath $runtimeLink) { [IO.Directory]::Delete($runtimeLink) } }
  $syncText = Get-Content -LiteralPath (Join-Path $root 'scripts\sync-runtime.ps1') -Raw
  foreach ($term in @('stagingPath','rollbackPath','Copy-UeefReleaseFiles','validate-framework.ps1')) {
    if ($syncText -notmatch [regex]::Escape($term)) { throw "Runtime sync is missing transactional control: $term" }
  }
  $statePath = Join-Path $codexHome 'ueef\UEEF-ACTIVE.json'
  $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
  if ($state.agent -ne 'test-agent') { throw 'Active state did not preserve the agent name.' }
  if ([IO.Path]::GetFullPath([string]$state.runtimePath) -ne [IO.Path]::GetFullPath($runtime)) { throw 'Active state runtime path is wrong.' }
  $loader = Get-Content -LiteralPath (Join-Path $runtime 'UEEF-LOADER.md') -Raw
  foreach ($term in @('environment-bootstrap','get-diff-impact.ps1','Agent and model routing:','Loaded: boot-loader, core-system')) {
    if ($loader -notmatch [regex]::Escape($term)) { throw "Generated loader missing: $term" }
  }
  $agents = Get-Content -LiteralPath (Join-Path $codexHome 'AGENTS.md') -Raw
  foreach ($term in @('# User rules','Keep this custom rule.','<!-- UEEF-MANAGED:START -->','<!-- UEEF-MANAGED:END -->')) {
    if ($agents -notmatch [regex]::Escape($term)) { throw "Runtime sync did not preserve managed AGENTS content: $term" }
  }
  foreach ($term in @('save-contract bugs','Repetition does not convert','external or user-only condition','no meaningful local work remains','When a goal is ACTIVE','read current goal status')) {
    if ($agents -notmatch [regex]::Escape($term)) { throw "Generated AGENTS missing delivery continuation contract: $term" }
  }
  foreach ($term in @('get-ueef-task-preflight.ps1','get-diff-impact.ps1','project memory only for explicit local decisions','not a T0/T1 checklist')) {
    if ($agents -notmatch [regex]::Escape($term)) { throw "Generated AGENTS missing optional-tool guidance: $term" }
  }
  $stateBeforeRollback = Get-Content -LiteralPath $statePath -Raw
  $agentsBeforeRollback = Get-Content -LiteralPath (Join-Path $codexHome 'AGENTS.md') -Raw
  $rollbackTriggered = $false
  try { & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent 'test-agent' -TestFailAfterState | Out-Null }
  catch { $rollbackTriggered = $_.Exception.Message -like '*Injected test failure*' }
  if (!$rollbackTriggered) { throw 'Runtime sync rollback injection did not fail.' }
  if ((Get-Content -LiteralPath $statePath -Raw) -cne $stateBeforeRollback) { throw 'Runtime sync did not restore the previous active state.' }
  if ((Get-Content -LiteralPath (Join-Path $codexHome 'AGENTS.md') -Raw) -cne $agentsBeforeRollback) { throw 'Runtime sync did not restore the previous AGENTS file.' }
  $freshCodexHome = Join-Path $sandbox 'fresh-codex-home'
  Initialize-FakeSkillInstaller $freshCodexHome
  $freshRollbackTriggered = $false
  try { & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $freshCodexHome -Agent 'fresh-agent' -TestFailAfterState | Out-Null }
  catch { $freshRollbackTriggered = $_.Exception.Message -like '*Injected test failure*' }
  if (!$freshRollbackTriggered) { throw 'First-install rollback injection did not fail.' }
  if (Test-Path -LiteralPath (Join-Path $freshCodexHome 'AGENTS.md')) { throw 'Failed first sync left a generated AGENTS file.' }
  if (Test-Path -LiteralPath (Join-Path $freshCodexHome 'ueef\UEEF-ACTIVE.json')) { throw 'Failed first sync left an active state.' }
  if (Test-Path -LiteralPath (Join-Path $freshCodexHome 'ueef\fresh-agent')) { throw 'Failed first sync left a runtime.' }
  $status = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef') -SkipRuntimeDrift)
  if ($status -notcontains 'Overall: ACTIVE') { throw "Valid generated runtime did not become ACTIVE: $($status -join ' | ')" }
  Set-Content -LiteralPath (Join-Path $runtime 'README.md') -Value 'intentional runtime drift' -Encoding utf8
  $driftStatus = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef'))
  if ($driftStatus -notcontains 'Runtime drift: FAIL' -or $driftStatus -notcontains 'Overall: INACTIVE') { throw 'Runtime drift did not invalidate ACTIVE status.' }
  & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent 'test-agent' | Out-Null
  $statusAfterRepair = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef'))
  if ($statusAfterRepair -notcontains 'Runtime drift: PASS' -or $statusAfterRepair -notcontains 'Overall: ACTIVE') { throw 'Runtime resync did not repair drift status.' }
  Add-Content -LiteralPath (Join-Path $runtime 'UEEF-LOADER.md') -Value "`nUnauthorized loader mutation." -Encoding utf8
  $loaderDriftStatus = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef'))
  if ($loaderDriftStatus -notcontains 'Runtime drift: FAIL' -or $loaderDriftStatus -notcontains 'Overall: INACTIVE') { throw 'Runtime status accepted a tampered loader.' }
  & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent 'test-agent' | Out-Null
  $untrackedStatusFixture = Join-Path $root 'docs\.ueef-untracked-runtime-test.tmp'
  try {
    Set-Content -LiteralPath $untrackedStatusFixture -Value 'untracked files are outside the release policy'
    $statusWithUntrackedSource = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef'))
    if ($statusWithUntrackedSource -notcontains 'Runtime drift: PASS' -or $statusWithUntrackedSource -notcontains 'Overall: ACTIVE') { throw 'Runtime status disagrees with the tracked-file release policy.' }
  } finally { Remove-Item -LiteralPath $untrackedStatusFixture -Force -ErrorAction SilentlyContinue }
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
