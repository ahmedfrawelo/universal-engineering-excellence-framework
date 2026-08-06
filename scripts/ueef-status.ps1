param(
  [string]$RepositoryPath = (Split-Path -Parent $PSScriptRoot),
  [string]$GlobalPath = "",
  [switch]$SkipRuntimeDrift,
  [switch]$RefreshRuntimeDrift,
  [switch]$Json
)
$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepositoryPath)) {
  throw 'RepositoryPath cannot be empty.'
}
try {
  $RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath -ErrorAction Stop).Path
} catch {
  throw "RepositoryPath does not exist: $RepositoryPath"
}
if ([string]::IsNullOrWhiteSpace($GlobalPath)) {
  $repoLeaf = Split-Path -Leaf $RepositoryPath
  $repoParent = Split-Path -Parent $RepositoryPath
  if ($repoLeaf -eq "codex" -and (Split-Path -Leaf $repoParent) -eq "ueef") {
    $GlobalPath = $repoParent
  } elseif ($env:UEEF_GLOBAL_PATH) {
    $GlobalPath = $env:UEEF_GLOBAL_PATH
  } elseif ($env:CODEX_HOME) {
    $GlobalPath = Join-Path $env:CODEX_HOME "ueef"
  } else {
    $GlobalPath = Join-Path (Split-Path -Parent $RepositoryPath) "ueef-runtime"
  }
}

function Test-Item($path) { return [bool](Test-Path -LiteralPath $path) }
function PassFail($condition) { if ($condition) { "PASS" } else { "FAIL" } }
function Test-ManagedEnforcementState($State, [string]$ExpectedRuntimePath, [string]$ExpectedHooksPath) {
  $managed = $State.managedEnforcement
  if ($null -eq $managed -or $managed.required -ne $true -or $managed.contractVersion -ne 1) { return $false }
  try {
    $hooksPath = [IO.Path]::GetFullPath([string]$managed.hooksPath).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if ($hooksPath -ne [IO.Path]::GetFullPath($ExpectedHooksPath).TrimEnd([IO.Path]::DirectorySeparatorChar)) { return $false }
    $requirementsPath = [IO.Path]::GetFullPath([string]$managed.requirementsPath)
    if (!(Test-Path -LiteralPath $requirementsPath -PathType Leaf) -or !(Test-Path -LiteralPath $hooksPath -PathType Container)) { return $false }
    if (((Get-Item -LiteralPath $requirementsPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or ((Get-Item -LiteralPath $hooksPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
    if ((Get-FileHash -LiteralPath $requirementsPath -Algorithm SHA256).Hash -ne ([string]$managed.requirementsSha256).ToUpperInvariant()) { return $false }
    $nodePath = [IO.Path]::GetFullPath([string]$managed.nodePath)
    if (!(Test-Path -LiteralPath $nodePath -PathType Leaf) -or (Get-FileHash -LiteralPath $nodePath -Algorithm SHA256).Hash -ne ([string]$managed.nodeSha256).ToUpperInvariant()) { return $false }
    $requirementsText = [IO.File]::ReadAllText($requirementsPath, [Text.Encoding]::UTF8)
    if (!$requirementsText.StartsWith('# UEEF-MANAGED-REQUIREMENTS', [StringComparison]::Ordinal) -or
        $requirementsText -notmatch '(?m)^hooks\s*=\s*true\s*$' -or
        $requirementsText -notmatch '(?m)^command_windows\s*=\s*''node\s+"[^"\r\n]+ueef-codex-hook\.mjs"''\s*$') { return $false }
    $expectedNames = @('ueef-codex-hook.mjs','record-ueef-route.mjs','ueef-hook-common.mjs','codex-enforcement-policy.json','model-routing-policy.json','resolve-model-route.mjs','codex-app-server-models.mjs','codex-app-server-client-lib.mjs')
    $files = @($managed.hookFiles)
    if ($files.Count -ne $expectedNames.Count) { return $false }
    foreach ($name in $expectedNames) {
      $record = @($files | Where-Object { [string]$_.relativePath -ceq $name })
      if ($record.Count -ne 1) { return $false }
      $path = Join-Path $hooksPath $name
      if (!(Test-Path -LiteralPath $path -PathType Leaf) -or ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
      if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne ([string]$record[0].sha256).ToUpperInvariant()) { return $false }
    }
    return $true
  } catch { return $false }
}

function Test-EffectiveManagedEnforcement([string]$Executable, [string]$ExpectedHooksPath, [string]$ProbePath) {
  try {
    if (!(Test-Path -LiteralPath $Executable -PathType Leaf) -or !(Test-Path -LiteralPath $ProbePath -PathType Leaf)) { return $false }
    $node = Get-Command node -ErrorAction Stop
    $json = (& $node.Source $ProbePath --executable $Executable --timeout-ms 15000 | Select-Object -Last 1)
    if ([string]::IsNullOrWhiteSpace($json)) { return $false }
    $probe = $json | ConvertFrom-Json
    $requirements = $probe.data.requirements.requirements
    if ($probe.provenance.provider -ne 'codex-app-server:configRequirements/read' -or $requirements.featureRequirements.hooks -ne $true) { return $false }
    $hooks = $requirements.hooks
    $managedPath = if ($IsWindows -or $env:OS -eq 'Windows_NT') { [string]$hooks.windowsManagedDir } else { [string]$hooks.managedDir }
    if ([IO.Path]::GetFullPath($managedPath).TrimEnd([IO.Path]::DirectorySeparatorChar) -ne [IO.Path]::GetFullPath($ExpectedHooksPath).TrimEnd([IO.Path]::DirectorySeparatorChar)) { return $false }
    foreach ($eventName in @('SessionStart','UserPromptSubmit','PreToolUse','PostToolUse','Stop')) {
      $groups = @($hooks.$eventName)
      if ($groups.Count -ne 1 -or @($groups[0].hooks).Count -ne 1) { return $false }
      $handler = @($groups[0].hooks)[0]
      $command = if ($IsWindows -or $env:OS -eq 'Windows_NT') { [string]$handler.commandWindows } else { [string]$handler.command }
      if ($command -notmatch '^node\s+"[^"\r\n]+ueef-codex-hook\.mjs"$') { return $false }
    }
    return $true
  } catch { return $false }
}

$repoExists = Test-Item $RepositoryPath
$versionPath = Join-Path $RepositoryPath "VERSION.md"
$version = "UNKNOWN"
if (Test-Item $versionPath) {
  $versionText = Get-Content -LiteralPath $versionPath -Raw
  $match = [regex]::Match($versionText, "version:\s*([0-9]+\.[0-9]+\.[0-9]+)", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if ($match.Success) { $version = $match.Groups[1].Value }
}

$rootFiles = @("README.md","INSTALL.md","QUICK_START.md","BUILD_PROGRESS.md")
$coreFiles = @(
  "framework/01-core/00-core-system.md",
  "framework/01-core/01-master-loader.md",
  "framework/01-core/02-master-index.md",
  "framework/01-core/10-runtime-activation-proof.md",
  "framework/01-core/11-ueef-status-check.md",
  "framework/01-core/12-ueef-required-preflight.md"
)
$rootPass = $repoExists -and !(($rootFiles | Where-Object { !(Test-Item (Join-Path $RepositoryPath $_)) }).Count)
$corePass = $repoExists -and !(($coreFiles | Where-Object { !(Test-Item (Join-Path $RepositoryPath $_)) }).Count)
$masterLoaderPass = Test-Item (Join-Path $RepositoryPath "framework/01-core/01-master-loader.md")
$masterIndexPass = (Test-Item (Join-Path $RepositoryPath "framework/01-core/02-master-index.md")) -or (Test-Item (Join-Path $RepositoryPath "framework/MASTER_INDEX.md"))
$activationProofPass = Test-Item (Join-Path $RepositoryPath "framework/01-core/10-runtime-activation-proof.md")
$activationGatePass = Test-Item (Join-Path $RepositoryPath "framework/12-delivery-quality/04-quality-gates/16-ueef-activation-gate.md")
$qualityGatesPass = Test-Item (Join-Path $RepositoryPath "framework/12-delivery-quality/04-quality-gates")
$validationPass = Test-Item (Join-Path $RepositoryPath "scripts/validate-framework.ps1")
$repositoryIntelligenceFiles = @(
  'framework/20-repository-evolution/03-repository-intelligence/00-repository-intelligence-system.md',
  'scripts/repository-intelligence.ps1',
  'scripts/repository-intelligence.sh',
  'config/repository-intelligence-policy.json',
  'engines/repository-intelligence/UEEF-UPSTREAM.json',
  'engines/repository-intelligence/UPSTREAM-FILES.json'
)
$repositoryIntelligencePass = !(($repositoryIntelligenceFiles | Where-Object { !(Test-Item (Join-Path $RepositoryPath $_)) }).Count)
$routePs = Join-Path $RepositoryPath 'scripts/select-agent-route.ps1'
$routeSh = Join-Path $RepositoryPath 'scripts/select-agent-route.sh'
$contractFiles = @($routePs, $routeSh, (Join-Path $RepositoryPath 'UEEF-LOADER.md'), (Join-Path $RepositoryPath 'framework/19-agent-workflow/01-model-orchestration/00-agent-model-orchestration-system.md'), (Join-Path $RepositoryPath 'framework/12-delivery-quality/04-quality-gates/31-agent-model-routing-gate.md'))
$contractFilesPass = !(($contractFiles | Where-Object { !(Test-Item $_) }).Count)
$routingText = if ($contractFilesPass) { ($contractFiles | ForEach-Object { Get-Content -LiteralPath $_ -Raw }) -join "`n" } else { '' }
$agentRoutingPass = $contractFilesPass -and $routingText -match 'reasoningCeiling' -and $routingText -match 'TOOL_UNAVAILABLE' -and $routingText -match 'Visible pre-command route line|Before the first project command or edit' -and $routingText -match 'routeEvidenceRequired' -and $routingText -match 'noSpawnReason' -and $routingText -match 'proportional'
$isManagedRuntime = (Split-Path -Leaf (Split-Path -Parent $RepositoryPath)) -eq "ueef"
$codexHome = if ($isManagedRuntime) { Split-Path -Parent $GlobalPath } elseif ($env:CODEX_HOME) { $env:CODEX_HOME } else { Split-Path -Parent $GlobalPath }
$agentsPath = Join-Path $codexHome "AGENTS.md"
$managedEnforcementPass = $true
$managedEnforcementEffectiveRequired = $false
$managedEnforcementEffectivePass = $true
if ($isManagedRuntime) {
  $agentsText = if (Test-Item $agentsPath) { Get-Content -LiteralPath $agentsPath -Raw } else { "" }
  $agentsVersionPattern = '\(version\s+' + [regex]::Escape($version) + '\)'
  $agentsPass = (Test-Item $agentsPath) -and (($agentsText -match [regex]::Escape($GlobalPath)) -or ($agentsText -match [regex]::Escape($RepositoryPath))) -and $agentsText -match 'T0/T1 stay single-agent|T1 defaults to single-agent' -and $agentsText -match 'route rationale' -and $agentsText -match $agentsVersionPattern
  $activeStatePath = Join-Path $GlobalPath "UEEF-ACTIVE.json"
  $activeStatePass = $false
  if (Test-Item $activeStatePath) {
    try {
      $state = Get-Content -LiteralPath $activeStatePath -Raw | ConvertFrom-Json
      $expectedRuntime = [IO.Path]::GetFullPath($RepositoryPath).TrimEnd([IO.Path]::DirectorySeparatorChar)
      $stateRuntime = [IO.Path]::GetFullPath([string]$state.runtimePath).TrimEnd([IO.Path]::DirectorySeparatorChar)
      $stateLoader = [IO.Path]::GetFullPath([string]$state.loaderPath)
      $expectedLoader = [IO.Path]::GetFullPath((Join-Path $RepositoryPath 'UEEF-LOADER.md'))
      $expectedAgent = Split-Path -Leaf $RepositoryPath
      $stateAgent = [string]$state.agent
      $codexRuntime = $expectedAgent -ieq 'codex'
      $requiredCheckNames = @('loader','agents','coreSystem','masterLoader','masterIndex','activationGate','statusScript','managedRequirements','managedHooks')
      $checksPass = $state.requiredChecks -and !(@($requiredCheckNames | Where-Object {
        $property = $state.requiredChecks.psobject.Properties[$_]
        !$property -or $property.Value -ne $true
      }).Count) -and !(@($state.requiredChecks.psobject.Properties | Where-Object { $_.Value -ne $true }).Count)
      if ($state.requireAgents -ne $true -and !$codexRuntime) { $agentsPass = $true }
      $loaderHashPass = ![string]::IsNullOrWhiteSpace([string]$state.runtimeLoaderSha256) -and (Get-FileHash -LiteralPath $expectedLoader -Algorithm SHA256).Hash -ceq ([string]$state.runtimeLoaderSha256).ToUpperInvariant()
      $managedEnforcementPass = !$codexRuntime -or (Test-ManagedEnforcementState $state $expectedRuntime (Join-Path $GlobalPath 'managed-hooks'))
      if ($codexRuntime) {
        $appServerCandidates = @(
          (Join-Path $codexHome 'plugins\.plugin-appserver\codex.exe'),
          (Join-Path $codexHome '.sandbox-bin\codex.exe')
        )
        $appServerExecutable = @($appServerCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1)
        $managedEnforcementEffectiveRequired = $appServerExecutable.Count -eq 1
        if ($managedEnforcementEffectiveRequired) {
          $managedEnforcementEffectivePass = Test-EffectiveManagedEnforcement $appServerExecutable[0] (Join-Path $GlobalPath 'managed-hooks') (Join-Path $RepositoryPath 'scripts\codex-app-server-requirements.mjs')
        }
      }
      $activeStatePass = $state.active -eq $true -and $state.version -eq $version -and $stateAgent -eq $expectedAgent -and (!$codexRuntime -or $state.requireAgents -eq $true) -and $state.agentRoutingContractVersion -eq 4 -and $state.reasoningCeiling -eq 'proportional' -and $stateRuntime -eq $expectedRuntime -and $stateLoader -eq $expectedLoader -and $loaderHashPass -and $checksPass -and $managedEnforcementPass
    } catch { $activeStatePass = $false; $managedEnforcementPass = $false; $managedEnforcementEffectivePass = $false }
  }
} else {
  $agentsPass = $true
  $activeStatePath = Join-Path $GlobalPath "UEEF-ACTIVE.json"
  $activeStatePass = $true
}
$oldHomePath = Join-Path $HOME ".ueef"
$oldHomeAbsent = !(Test-Item $oldHomePath)
$runtimeDriftPass = $true
$runtimeDriftStatus = "SKIPPED"
$runtimeDriftMode = "SKIPPED"
$sourceRevisionStatus = "SKIPPED"
if (!$SkipRuntimeDrift -and $isManagedRuntime -and (Test-Item $activeStatePath)) {
  try {
    $stateForDrift = Get-Content -LiteralPath $activeStatePath -Raw | ConvertFrom-Json
    $sourceForDrift = [string]$stateForDrift.sourceRepositoryPath
    if (![string]::IsNullOrWhiteSpace($sourceForDrift) -and (Test-Item $sourceForDrift)) {
      . (Join-Path $RepositoryPath 'scripts\runtime-file-policy.ps1')
      $expectedLoaderHash = [string]$stateForDrift.runtimeLoaderSha256
      $contentSignature = Get-UeefRuntimeContentSignature -SourcePath $sourceForDrift -RuntimePath $RepositoryPath -ExpectedLoaderHash $expectedLoaderHash
      $cachePath = Join-Path $GlobalPath 'logs\runtime-drift-cache.json'
      $cacheHit = $false
      if (!$RefreshRuntimeDrift -and (Test-Path -LiteralPath $cachePath -PathType Leaf)) {
        try {
          $cache = Get-Content -LiteralPath $cachePath -Raw | ConvertFrom-Json
          $cacheHit = $cache.schemaVersion -eq 2 -and $cache.runtimePath -eq $RepositoryPath -and
            $cache.sourcePath -eq $sourceForDrift -and $cache.contentSignature -ceq $contentSignature -and $cache.result -eq 'PASS'
        } catch { $cacheHit = $false }
      }
      if ($cacheHit) {
        $runtimeDriftPass = $true
        $runtimeDriftMode = 'CACHED_CONTENT_VERIFIED'
      } else {
        $runtimeDriftPass = !(@(Get-UeefRuntimeDriftMismatches -SourcePath $sourceForDrift -RuntimePath $RepositoryPath -ExpectedLoaderHash $expectedLoaderHash).Count)
        $runtimeDriftMode = 'FULL_CONTENT_HASH'
        if ($runtimeDriftPass) {
          $cacheDirectory = Split-Path -Parent $cachePath
          New-Item -ItemType Directory -Path $cacheDirectory -Force | Out-Null
          $cacheDocument = [ordered]@{ schemaVersion=2; generatedAt=(Get-Date).ToUniversalTime().ToString('o'); sourcePath=$sourceForDrift; runtimePath=$RepositoryPath; contentSignature=$contentSignature; result='PASS' }
          $temporaryCache = "$cachePath.$([guid]::NewGuid().ToString('N')).tmp"
          [IO.File]::WriteAllText($temporaryCache, ($cacheDocument | ConvertTo-Json -Depth 3), [Text.UTF8Encoding]::new($false))
          Move-Item -LiteralPath $temporaryCache -Destination $cachePath -Force
        }
      }
      $runtimeDriftStatus = if ($runtimeDriftPass) { "PASS" } else { "FAIL" }
      $recordedSourceCommit = [string]$stateForDrift.sourceCommit
      $currentSourceCommit = ''
      try { $currentSourceCommit = (git -c "safe.directory=$sourceForDrift" -C $sourceForDrift rev-parse HEAD 2>$null | Select-Object -First 1).Trim() } catch { $currentSourceCommit = '' }
      if ($recordedSourceCommit -and $recordedSourceCommit -ne 'UNKNOWN' -and $currentSourceCommit) {
        $sourceRevisionStatus = if ($recordedSourceCommit -eq $currentSourceCommit) { 'PASS' } else { 'WARN_OUTDATED' }
      }
    }
  } catch {
    $runtimeDriftPass = $false
    $runtimeDriftStatus = "FAIL"
  }
}
$engineGeneratedPattern = '[\\/]engines[\\/]repository-intelligence[\\/](?:\.venv|build|graphifyy\.egg-info|__pycache__|\.pytest_cache|\.hypothesis|\.ruff_cache|\.mypy_cache)(?:[\\/]|$)'
$markdownCount = if ($repoExists) { (Get-ChildItem -LiteralPath $RepositoryPath -Recurse -Filter *.md -File | Where-Object { $_.FullName -notmatch '[\\/](?:\.git|\.ueef)[\\/]' -and $_.FullName -notmatch $engineGeneratedPattern }).Count } else { 0 }
$globalExists = Test-Item $GlobalPath
$loaderCandidates = @()
if ($globalExists) {
  $loaderCandidates = Get-ChildItem -LiteralPath $GlobalPath -Recurse -Filter "UEEF-LOADER.md" -File -ErrorAction SilentlyContinue
}
$globalLoaderStatus = if (!$globalExists) { "UNKNOWN" } elseif ($loaderCandidates.Count -gt 0) { "PASS" } else { "FAIL" }
$installed = if ($isManagedRuntime -and $repoExists -and $globalExists -and $loaderCandidates.Count -gt 0) { "YES" } else { "NO" }
$sourceValidationPass = $repoExists -and $rootPass -and $corePass -and $masterLoaderPass -and $masterIndexPass -and $activationProofPass -and $activationGatePass -and $qualityGatesPass -and $validationPass -and $agentRoutingPass -and $repositoryIntelligencePass
$managedIntegrityPass = $agentsPass -and $activeStatePass -and $managedEnforcementPass -and $managedEnforcementEffectivePass -and $oldHomeAbsent -and $runtimeDriftPass
$overall = if ($isManagedRuntime) {
  if ($installed -eq "YES" -and $sourceValidationPass -and $managedIntegrityPass) { "ACTIVE" } else { "INACTIVE" }
} elseif ($sourceValidationPass) {
  "SOURCE_VALIDATED"
} else {
  "SOURCE_INVALID"
}

$statusResult = [ordered]@{
  schemaVersion = 2
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  version = $version
  installed = $installed
  mode = if ($isManagedRuntime) { 'managed-runtime' } else { 'source-checkout' }
  sourceValidation = PassFail $sourceValidationPass
  activationClaim = if ($isManagedRuntime) { if ($overall -eq 'ACTIVE') { 'ACTIVE_RUNTIME' } else { 'INACTIVE_RUNTIME' } } else { 'SOURCE_ONLY_NOT_INSTALLED' }
  repositoryPath = '<runtime-root>'
  globalPath = '<global-root>'
  overall = $overall
  checks = [ordered]@{
    coreFiles = (PassFail $corePass)
    masterLoader = (PassFail $masterLoaderPass)
    masterIndex = (PassFail $masterIndexPass)
    activationProof = (PassFail $activationProofPass)
    activationGate = (PassFail $activationGatePass)
    qualityGates = (PassFail $qualityGatesPass)
    globalLoader = $globalLoaderStatus
    agents = if ($isManagedRuntime) { (PassFail $agentsPass) } else { 'NOT_APPLICABLE' }
    agentRouting = (PassFail $agentRoutingPass)
    repositoryIntelligence = (PassFail $repositoryIntelligencePass)
    activeState = if ($isManagedRuntime) { (PassFail $activeStatePass) } else { 'NOT_APPLICABLE' }
    managedEnforcement = if ($isManagedRuntime) { (PassFail $managedEnforcementPass) } else { 'NOT_APPLICABLE' }
    managedEnforcementEffective = if (!$isManagedRuntime -or !$managedEnforcementEffectiveRequired) { 'NOT_APPLICABLE' } else { (PassFail $managedEnforcementEffectivePass) }
    runtimeDrift = if ($isManagedRuntime) { $runtimeDriftStatus } else { 'NOT_APPLICABLE' }
    runtimeDriftMode = if ($isManagedRuntime) { $runtimeDriftMode } else { 'NOT_APPLICABLE' }
    sourceRevision = $sourceRevisionStatus
    validationScript = (PassFail $validationPass)
  }
}
if ($Json) { $statusResult | ConvertTo-Json -Depth 5; exit 0 }

Write-Output "UEEF Status"
Write-Output "-----------"
Write-Output "Installed: $installed"
Write-Output "Repository Path: $RepositoryPath"
Write-Output "Global Path: $GlobalPath"
Write-Output "Version: $version"
Write-Output "Mode: $(if ($isManagedRuntime) { 'managed-runtime' } else { 'source-checkout' })"
Write-Output "Core files: $(PassFail $corePass)"
Write-Output "Master loader: $(PassFail $masterLoaderPass)"
Write-Output "Master index: $(PassFail $masterIndexPass)"
Write-Output "Runtime activation proof: $(PassFail $activationProofPass)"
Write-Output "Activation gate: $(PassFail $activationGatePass)"
Write-Output "Quality gates: $(PassFail $qualityGatesPass)"
Write-Output "Markdown file count: $markdownCount"
Write-Output "Global loader: $(if ($isManagedRuntime) { $globalLoaderStatus } else { 'NOT_APPLICABLE' })"
Write-Output "Codex AGENTS: $(if ($isManagedRuntime) { PassFail $agentsPass } else { 'NOT_APPLICABLE' })"
Write-Output "Agent routing contract: $(PassFail $agentRoutingPass)"
Write-Output "Repository intelligence: $(PassFail $repositoryIntelligencePass)"
Write-Output "Active state: $(if ($isManagedRuntime) { PassFail $activeStatePass } else { 'NOT_APPLICABLE' })"
Write-Output "Managed enforcement: $(if ($isManagedRuntime) { PassFail $managedEnforcementPass } else { 'NOT_APPLICABLE' })"
Write-Output "Managed enforcement effective: $(if (!$isManagedRuntime -or !$managedEnforcementEffectiveRequired) { 'NOT_APPLICABLE' } else { PassFail $managedEnforcementEffectivePass })"
Write-Output "Runtime drift: $(if ($isManagedRuntime) { $runtimeDriftStatus } else { 'NOT_APPLICABLE' })"
Write-Output "Runtime drift mode: $(if ($isManagedRuntime) { $runtimeDriftMode } else { 'NOT_APPLICABLE' })"
Write-Output "Runtime source revision: $sourceRevisionStatus"
if ($sourceRevisionStatus -eq 'WARN_OUTDATED') { Write-Output 'Required action: Sync the runtime before relying on updated intent or browser policies.' }
Write-Output "Old HOME .ueef absent: $(if ($isManagedRuntime) { PassFail $oldHomeAbsent } else { 'NOT_APPLICABLE' })"
if ($isManagedRuntime -and $globalLoaderStatus -ne "PASS") {
  Write-Output "Required action: Run scripts/install-codex.ps1, scripts/install-cursor.ps1, or scripts/install-generic.ps1 from Codex with CODEX_HOME set, or set UEEF_GLOBAL_PATH to the Codex runtime path containing UEEF-LOADER.md."
}
if (!$isManagedRuntime -and $overall -eq 'SOURCE_VALIDATED') {
  Write-Output "Source checkout validated. Activation is not claimed until scripts/sync-runtime.ps1 installs this source into the managed Codex runtime."
}
Write-Output "Validation script: $(PassFail $validationPass)"
Write-Output "Overall: $overall"
