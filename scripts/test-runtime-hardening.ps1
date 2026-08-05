$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ("ueef-rt-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
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
  try { & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent '..\escape' -Quiet | Out-Null }
  catch { $unsafeRejected = $true }
  if (!$unsafeRejected) { throw 'Unsafe agent path was accepted.' }
  if (Test-Path -LiteralPath (Join-Path $sandbox 'escape')) { throw 'Unsafe agent path wrote outside runtime root.' }

  $overlapSource = Join-Path $sandbox 'overlap-source'
  New-Item -ItemType Directory -Path (Join-Path $overlapSource 'framework') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $overlapSource 'VERSION.md') -Value 'version: 0.0.0.'
  $overlapRejected = $false
  try { & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $overlapSource -CodexHome (Join-Path $overlapSource 'codex-home') -Agent 'test-agent' -Quiet | Out-Null } catch { $overlapRejected = $_.Exception.Message -like '*overlapping source and CODEX_HOME*' }
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
  & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent 'codex' -Quiet | Out-Null
  $runtime = Join-Path $codexHome 'ueef\codex'
  $runtimeRoot = Join-Path $codexHome 'ueef'
  $staleTransaction = Join-Path $runtimeRoot '.sdeadbeef'
  $nonTransaction = Join-Path $runtimeRoot '.snot-a-transaction'
  New-Item -ItemType Directory -Path $staleTransaction,$nonTransaction | Out-Null
  (Get-Item -LiteralPath $staleTransaction).LastWriteTime = (Get-Date).AddMinutes(-11)
  & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent 'codex' -Quiet | Out-Null
  if (Test-Path -LiteralPath $staleTransaction) { throw 'Runtime sync retained a stale transaction directory.' }
  if (!(Test-Path -LiteralPath $nonTransaction)) { throw 'Runtime sync removed a non-transaction directory.' }
  Remove-Item -LiteralPath $nonTransaction -Recurse -Force
  $sentinel = Join-Path $runtime 'active-task-sentinel.txt'
  Set-Content -LiteralPath $sentinel -Value 'must be removed because it is not part of the release' -Encoding utf8
  & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent 'codex' -Quiet | Out-Null
  if (Test-Path -LiteralPath $sentinel) { throw 'Runtime sync retained an unowned root file.' }
  $staleRuntimeFile = Join-Path $runtime 'framework\stale-runtime-file.md'
  Set-Content -LiteralPath $staleRuntimeFile -Value 'must be pruned from owned runtime folders' -Encoding utf8
  & (Join-Path $root 'scripts\check-runtime-drift.ps1') -SourcePath $root -RuntimePath $runtime | Out-Null
  $staleDetected = $LASTEXITCODE -ne 0
  if (!$staleDetected) { throw 'Runtime drift check accepted a stale file inside an owned runtime folder.' }
  & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent 'codex' -Quiet | Out-Null
  if (Test-Path -LiteralPath $staleRuntimeFile) { throw 'Runtime sync left a stale file inside an owned runtime folder.' }
  $generatedRuntimeCache = Join-Path $runtime 'engines\repository-intelligence\.venv\cache.bin'
  New-Item -ItemType Directory -Path (Split-Path -Parent $generatedRuntimeCache) -Force | Out-Null
  Set-Content -LiteralPath $generatedRuntimeCache -Value 'generated environment cache'
  $generatedRuntimeMetadata = Join-Path $runtime 'engines\repository-intelligence\graphifyy.egg-info\PKG-INFO'
  New-Item -ItemType Directory -Path (Split-Path -Parent $generatedRuntimeMetadata) -Force | Out-Null
  Set-Content -LiteralPath $generatedRuntimeMetadata -Value 'generated package metadata'
  $generatedCacheMismatches = @(Get-UeefRuntimeDriftMismatches -SourcePath $root -RuntimePath $runtime)
  if ($generatedCacheMismatches | Where-Object { $_ -like '*engines/repository-intelligence/.venv*' }) { throw 'Runtime drift rejected the bounded generated repository-intelligence environment.' }
  if ($generatedCacheMismatches | Where-Object { $_ -like '*engines/repository-intelligence/graphifyy.egg-info*' }) { throw 'Runtime drift rejected bounded generated repository-intelligence package metadata.' }
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
  if ($state.agent -ne 'codex' -or $state.requireAgents -ne $true) { throw 'Active state did not preserve the Codex agent and RequireAgents contract.' }
  if ($state.managedEnforcement.required -ne $true -or $state.managedEnforcement.contractVersion -ne 1) { throw 'Active state did not require managed enforcement.' }
  $managedRequirementsPath = [string]$state.managedEnforcement.requirementsPath
  $managedHooksPath = [string]$state.managedEnforcement.hooksPath
  if (!(Test-Path -LiteralPath $managedRequirementsPath -PathType Leaf) -or !(Test-Path -LiteralPath $managedHooksPath -PathType Container)) { throw 'Managed requirements or hook payload was not installed.' }
  if ([IO.Path]::GetFullPath([string]$state.runtimePath) -ne [IO.Path]::GetFullPath($runtime)) { throw 'Active state runtime path is wrong.' }
  $stateBeforeWriterGuard = [IO.File]::ReadAllText($statePath, [Text.Encoding]::UTF8)
  $writerGuardRejected = $false
  try {
    & (Join-Path $runtime 'scripts\write-active-state.ps1') -RepositoryPath $runtime -CodexHome $codexHome -RuntimeRoot $runtimeRoot -Agent 'codex' -SourceRepositoryPath $root | Out-Null
  } catch { $writerGuardRejected = $_.Exception.Message -like '*without -RequireAgents*' }
  if (!$writerGuardRejected) { throw 'Codex active-state writer accepted a state without RequireAgents.' }
  if ([IO.File]::ReadAllText($statePath, [Text.Encoding]::UTF8) -cne $stateBeforeWriterGuard) { throw 'Rejected Codex active-state write changed the existing state.' }
  $loader = [IO.File]::ReadAllText((Join-Path $runtime 'UEEF-LOADER.md'), [Text.Encoding]::UTF8)
  foreach ($term in @('environment-bootstrap','get-diff-impact.ps1','Agent and model routing:','Loaded: boot-loader, core-system')) {
    if ($loader -notmatch [regex]::Escape($term)) { throw "Generated loader missing: $term" }
  }
  $arabicBypassCodex = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('2KrYrNin2YjYsiBVRUVG'))
  if (!$loader.Contains($arabicBypassCodex)) { throw 'Generated loader lost the Arabic Codex FREE-MODE phrase.' }
  $agents = Get-Content -LiteralPath (Join-Path $codexHome 'AGENTS.md') -Raw
  if ($agents.Length -gt 2200) { throw "Generated AGENTS is too large for a precedence-only runtime block: $($agents.Length) characters." }
  foreach ($term in @('Precedence: Scope wins','stop when done','T0/T1 stay single-agent','economical default, not a hard ceiling','read the loader once per task','browser control is explicit-task only','For browser-required tasks, use the installed Chrome control plugin automatically on a dedicated task tab','Never launch Playwright, chrome-devtools','IDE Simple Browser','a second profile, or a new context','ask only for external missing access or authorized emergency fallback')) {
    if ($agents -notmatch [regex]::Escape($term)) { throw "Generated AGENTS missing compact precedence contract: $term" }
  }
  foreach ($term in @('# User rules','Keep this custom rule.','<!-- UEEF-MANAGED:START -->','<!-- UEEF-MANAGED:END -->')) {
    if ($agents -notmatch [regex]::Escape($term)) { throw "Runtime sync did not preserve managed AGENTS content: $term" }
  }
  $stateBeforeRollback = Get-Content -LiteralPath $statePath -Raw
  $agentsBeforeRollback = Get-Content -LiteralPath (Join-Path $codexHome 'AGENTS.md') -Raw
  $managedRequirementsBeforeRollback = [IO.File]::ReadAllText($managedRequirementsPath, [Text.Encoding]::UTF8)
  $managedHookHashesBeforeRollback = @($state.managedEnforcement.hookFiles | ForEach-Object { (Get-FileHash -LiteralPath (Join-Path $managedHooksPath ([string]$_.relativePath)) -Algorithm SHA256).Hash })
  $rollbackTriggered = $false
  try { & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent 'codex' -TestFailAfterState -Quiet | Out-Null }
  catch { $rollbackTriggered = $_.Exception.Message -like '*Injected test failure*' }
  if (!$rollbackTriggered) { throw 'Runtime sync rollback injection did not fail.' }
  if ((Get-Content -LiteralPath $statePath -Raw) -cne $stateBeforeRollback) { throw 'Runtime sync did not restore the previous active state.' }
  if ((Get-Content -LiteralPath (Join-Path $codexHome 'AGENTS.md') -Raw) -cne $agentsBeforeRollback) { throw 'Runtime sync did not restore the previous AGENTS file.' }
  if ([IO.File]::ReadAllText($managedRequirementsPath, [Text.Encoding]::UTF8) -cne $managedRequirementsBeforeRollback) { throw 'Runtime sync did not restore managed requirements.' }
  $managedHookHashesAfterRollback = @($state.managedEnforcement.hookFiles | ForEach-Object { (Get-FileHash -LiteralPath (Join-Path $managedHooksPath ([string]$_.relativePath)) -Algorithm SHA256).Hash })
  if (($managedHookHashesAfterRollback -join ',') -cne ($managedHookHashesBeforeRollback -join ',')) { throw 'Runtime sync did not restore managed hook payload.' }
  $freshCodexHome = Join-Path $sandbox 'fresh-codex-home'
  Initialize-FakeSkillInstaller $freshCodexHome
  $freshRollbackTriggered = $false
  try { & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $freshCodexHome -Agent 'fresh-agent' -TestFailAfterState -Quiet | Out-Null }
  catch { $freshRollbackTriggered = $_.Exception.Message -like '*Injected test failure*' }
  if (!$freshRollbackTriggered) { throw 'First-install rollback injection did not fail.' }
  if (Test-Path -LiteralPath (Join-Path $freshCodexHome 'AGENTS.md')) { throw 'Failed first sync left a generated AGENTS file.' }
  if (Test-Path -LiteralPath (Join-Path $freshCodexHome 'ueef\UEEF-ACTIVE.json')) { throw 'Failed first sync left an active state.' }
  if (Test-Path -LiteralPath (Join-Path $freshCodexHome 'ueef\fresh-agent')) { throw 'Failed first sync left a runtime.' }
  $status = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef') -SkipRuntimeDrift)
  if ($status -notcontains 'Overall: ACTIVE') { throw "Valid generated runtime did not become ACTIVE: $($status -join ' | ')" }
  $bashPath = if (Test-Path 'C:\Program Files\Git\bin\bash.exe') { 'C:\Program Files\Git\bin\bash.exe' } else { '' }
  $integrityStateText = [IO.File]::ReadAllText($statePath, [Text.Encoding]::UTF8)
  $agentsPath = Join-Path $codexHome 'AGENTS.md'
  $integrityAgentsText = [IO.File]::ReadAllText($agentsPath, [Text.Encoding]::UTF8)
  $integrityRequirementsText = [IO.File]::ReadAllText($managedRequirementsPath, [Text.Encoding]::UTF8)
  $integrityHookPath = Join-Path $managedHooksPath 'ueef-codex-hook.mjs'
  $integrityHookText = [IO.File]::ReadAllText($integrityHookPath, [Text.Encoding]::UTF8)
  try {
    [IO.File]::AppendAllText($managedRequirementsPath, "# tampered`n", [Text.UTF8Encoding]::new($false))
    $invalidManagedStatus = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef') -SkipRuntimeDrift)
    if ($invalidManagedStatus -notcontains 'Managed enforcement: FAIL' -or $invalidManagedStatus -notcontains 'Overall: INACTIVE') { throw 'Windows status accepted tampered managed requirements.' }
    if ($bashPath) {
      $invalidManagedShellStatus = @(& $bashPath (Join-Path $runtime 'scripts\ueef-status.sh').Replace('\','/') 2>&1)
      if ($invalidManagedShellStatus -notcontains 'Managed enforcement: FAIL' -or $invalidManagedShellStatus -notcontains 'Overall: INACTIVE') { throw 'Unix status accepted tampered managed requirements.' }
    }
  } finally { [IO.File]::WriteAllText($managedRequirementsPath, $integrityRequirementsText, [Text.UTF8Encoding]::new($false)) }
  try {
    [IO.File]::AppendAllText($integrityHookPath, "# tampered`n", [Text.UTF8Encoding]::new($false))
    $invalidHookStatus = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef') -SkipRuntimeDrift)
    if ($invalidHookStatus -notcontains 'Managed enforcement: FAIL' -or $invalidHookStatus -notcontains 'Overall: INACTIVE') { throw 'Windows status accepted a tampered managed hook.' }
    if ($bashPath) {
      $invalidHookShellStatus = @(& $bashPath (Join-Path $runtime 'scripts\ueef-status.sh').Replace('\','/') 2>&1)
      if ($invalidHookShellStatus -notcontains 'Managed enforcement: FAIL' -or $invalidHookShellStatus -notcontains 'Overall: INACTIVE') { throw 'Unix status accepted a tampered managed hook.' }
    }
  } finally { [IO.File]::WriteAllText($integrityHookPath, $integrityHookText, [Text.UTF8Encoding]::new($false)) }
  try {
    $invalidCodexState = $integrityStateText | ConvertFrom-Json
    $invalidCodexState.requireAgents = $false
    [IO.File]::WriteAllText($statePath, ($invalidCodexState | ConvertTo-Json -Depth 8) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    $staleAgentsText = [regex]::Replace($integrityAgentsText, '\(version\s+\d+\.\d+\.\d+\)', '(version 0.0.0)')
    [IO.File]::WriteAllText($agentsPath, $staleAgentsText, [Text.UTF8Encoding]::new($false))
    $invalidCodexStatus = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef') -SkipRuntimeDrift)
    if ($invalidCodexStatus -notcontains 'Codex AGENTS: FAIL' -or $invalidCodexStatus -notcontains 'Active state: FAIL' -or $invalidCodexStatus -notcontains 'Overall: INACTIVE') {
      throw 'Windows status accepted requireAgents=false with stale Codex AGENTS.'
    }
    if ($bashPath) {
      $invalidShellStatus = @(& $bashPath (Join-Path $runtime 'scripts\ueef-status.sh').Replace('\','/') 2>&1)
      if ($invalidShellStatus -notcontains 'Codex AGENTS: FAIL' -or $invalidShellStatus -notcontains 'Active state: FAIL' -or $invalidShellStatus -notcontains 'Overall: INACTIVE') {
        throw 'Unix status accepted requireAgents=false with stale Codex AGENTS.'
      }
    }
  } finally {
    [IO.File]::WriteAllText($statePath, $integrityStateText, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($agentsPath, $integrityAgentsText, [Text.UTF8Encoding]::new($false))
  }
  if ($bashPath) {
    $decoyLoader = Join-Path $sandbox 'decoy-loader.md'
    Copy-Item -LiteralPath (Join-Path $runtime 'UEEF-LOADER.md') -Destination $decoyLoader
    try {
      $invalidPathState = $integrityStateText | ConvertFrom-Json
      $invalidPathState.runtimePath = Join-Path $runtimeRoot 'wrong-runtime'
      $invalidPathState.loaderPath = $decoyLoader
      $invalidPathState.runtimeLoaderSha256 = (Get-FileHash -LiteralPath $decoyLoader -Algorithm SHA256).Hash
      [IO.File]::WriteAllText($statePath, ($invalidPathState | ConvertTo-Json -Depth 8) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
      $invalidPathShellStatus = @(& $bashPath (Join-Path $runtime 'scripts\ueef-status.sh').Replace('\','/') 2>&1)
      if ($invalidPathShellStatus -notcontains 'Active state: FAIL' -or $invalidPathShellStatus -notcontains 'Overall: INACTIVE') {
        throw 'Unix status accepted active state bound to a different runtime and loader path.'
      }
    } finally {
      [IO.File]::WriteAllText($statePath, $integrityStateText, [Text.UTF8Encoding]::new($false))
      Remove-Item -LiteralPath $decoyLoader -Force -ErrorAction SilentlyContinue
    }
  }
  try {
    $missingChecksState = $integrityStateText | ConvertFrom-Json
    $missingChecksState.requiredChecks = [pscustomobject]@{}
    [IO.File]::WriteAllText($statePath, ($missingChecksState | ConvertTo-Json -Depth 8) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    $missingChecksStatus = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef') -SkipRuntimeDrift)
    if ($missingChecksStatus -notcontains 'Active state: FAIL' -or $missingChecksStatus -notcontains 'Overall: INACTIVE') {
      throw 'Windows status accepted active state with an empty requiredChecks object.'
    }
    if ($bashPath) {
      $missingChecksShellStatus = @(& $bashPath (Join-Path $runtime 'scripts\ueef-status.sh').Replace('\','/') 2>&1)
      if ($missingChecksShellStatus -notcontains 'Active state: FAIL' -or $missingChecksShellStatus -notcontains 'Overall: INACTIVE') {
        throw 'Unix status accepted active state with an empty requiredChecks object.'
      }
    }
  } finally {
    [IO.File]::WriteAllText($statePath, $integrityStateText, [Text.UTF8Encoding]::new($false))
  }
  try {
    $failedAdditionalCheckState = $integrityStateText | ConvertFrom-Json
    $failedAdditionalCheckState.requiredChecks | Add-Member -NotePropertyName futureCritical -NotePropertyValue $false
    [IO.File]::WriteAllText($statePath, ($failedAdditionalCheckState | ConvertTo-Json -Depth 8) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    $failedAdditionalCheckStatus = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef') -SkipRuntimeDrift)
    if ($failedAdditionalCheckStatus -notcontains 'Active state: FAIL' -or $failedAdditionalCheckStatus -notcontains 'Overall: INACTIVE') {
      throw 'Windows status accepted an additional failed required check.'
    }
    if ($bashPath) {
      $failedAdditionalCheckShellStatus = @(& $bashPath (Join-Path $runtime 'scripts\ueef-status.sh').Replace('\','/') 2>&1)
      if ($failedAdditionalCheckShellStatus -notcontains 'Active state: FAIL' -or $failedAdditionalCheckShellStatus -notcontains 'Overall: INACTIVE') {
        throw 'Unix status accepted an additional failed required check.'
      }
    }
  } finally {
    [IO.File]::WriteAllText($statePath, $integrityStateText, [Text.UTF8Encoding]::new($false))
  }
  $restoredIntegrityStatus = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef') -SkipRuntimeDrift)
  if ($restoredIntegrityStatus -notcontains 'Overall: ACTIVE') { throw 'Runtime did not recover after restoring valid Codex state and AGENTS.' }
  Set-Content -LiteralPath (Join-Path $runtime 'README.md') -Value 'intentional runtime drift' -Encoding utf8
  $driftStatus = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef'))
  if ($driftStatus -notcontains 'Runtime drift: FAIL' -or $driftStatus -notcontains 'Overall: INACTIVE') { throw 'Runtime drift did not invalidate ACTIVE status.' }
  & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent 'codex' -Quiet | Out-Null
  $statusAfterRepair = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef'))
  if ($statusAfterRepair -notcontains 'Runtime drift: PASS' -or $statusAfterRepair -notcontains 'Overall: ACTIVE') { throw 'Runtime resync did not repair drift status.' }
  Add-Content -LiteralPath (Join-Path $runtime 'UEEF-LOADER.md') -Value "`nUnauthorized loader mutation." -Encoding utf8
  $loaderDriftStatus = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef'))
  if ($loaderDriftStatus -notcontains 'Runtime drift: FAIL' -or $loaderDriftStatus -notcontains 'Overall: INACTIVE') { throw 'Runtime status accepted a tampered loader.' }
  & (Join-Path $root 'scripts\sync-runtime.ps1') -SourcePath $root -CodexHome $codexHome -Agent 'codex' -Quiet | Out-Null
  $untrackedStatusFixture = Join-Path $root 'docs\.ueef-untracked-runtime-test.tmp'
  try {
    Set-Content -LiteralPath $untrackedStatusFixture -Value 'untracked files are outside the release policy'
    $statusWithUntrackedSource = @(& (Join-Path $runtime 'scripts\ueef-status.ps1') -RepositoryPath $runtime -GlobalPath (Join-Path $codexHome 'ueef'))
    if ($statusWithUntrackedSource -notcontains 'Runtime drift: PASS' -or $statusWithUntrackedSource -notcontains 'Overall: ACTIVE') { throw 'Runtime status disagrees with the tracked-file release policy.' }
  } finally { Remove-Item -LiteralPath $untrackedStatusFixture -Force -ErrorAction SilentlyContinue }
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
  for ($cleanupAttempt = 1; $cleanupAttempt -le 10 -and (Test-Path -LiteralPath $sandbox); $cleanupAttempt++) {
    try { Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction Stop }
    catch {
      if ($cleanupAttempt -eq 10) {
        Write-Warning "Runtime hardening tests passed, but temporary sandbox cleanup could not finish: $sandbox"
        break
      }
      Start-Sleep -Milliseconds 250
    }
  }
}
