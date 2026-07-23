param(
  [string]$RepositoryPath = (Split-Path -Parent $PSScriptRoot),
  [string]$GlobalPath = "",
  [switch]$SkipRuntimeDrift,
  [switch]$Json
)
$ErrorActionPreference = "Stop"
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
$activationGatePass = Test-Item (Join-Path $RepositoryPath "framework/27-quality-gates/16-ueef-activation-gate.md")
$qualityGatesPass = Test-Item (Join-Path $RepositoryPath "framework/27-quality-gates")
$validationPass = Test-Item (Join-Path $RepositoryPath "scripts/validate-framework.ps1")
$routePs = Join-Path $RepositoryPath 'scripts/select-agent-route.ps1'
$routeSh = Join-Path $RepositoryPath 'scripts/select-agent-route.sh'
$contractFiles = @($routePs, $routeSh, (Join-Path $RepositoryPath 'UEEF-LOADER.md'), (Join-Path $RepositoryPath 'framework/58-agent-model-orchestration/00-agent-model-orchestration-system.md'), (Join-Path $RepositoryPath 'framework/27-quality-gates/31-agent-model-routing-gate.md'))
$contractFilesPass = !(($contractFiles | Where-Object { !(Test-Item $_) }).Count)
$routingText = if ($contractFilesPass) { ($contractFiles | ForEach-Object { Get-Content -LiteralPath $_ -Raw }) -join "`n" } else { '' }
$agentRoutingPass = $contractFilesPass -and $routingText -match 'reasoningCeiling' -and $routingText -match 'TOOL_UNAVAILABLE' -and $routingText -match 'Visible pre-command route line|Before the first project command or edit' -and $routingText -match 'routeEvidenceRequired' -and $routingText -match 'noSpawnReason' -and $routingText -match 'proportional'
$isManagedRuntime = (Split-Path -Leaf (Split-Path -Parent $RepositoryPath)) -eq "ueef"
$codexHome = if ($isManagedRuntime) { Split-Path -Parent $GlobalPath } elseif ($env:CODEX_HOME) { $env:CODEX_HOME } else { Split-Path -Parent $GlobalPath }
$agentsPath = Join-Path $codexHome "AGENTS.md"
if ($isManagedRuntime) {
  $agentsText = if (Test-Item $agentsPath) { Get-Content -LiteralPath $agentsPath -Raw } else { "" }
  $agentsPass = (Test-Item $agentsPath) -and (($agentsText -match [regex]::Escape($GlobalPath)) -or ($agentsText -match [regex]::Escape($RepositoryPath))) -and $agentsText -match 'T0/T1 stay single-agent|T1 defaults to single-agent' -and $agentsText -match 'route rationale'
  $activeStatePath = Join-Path $GlobalPath "UEEF-ACTIVE.json"
  $activeStatePass = $false
  if (Test-Item $activeStatePath) {
    try {
      $state = Get-Content -LiteralPath $activeStatePath -Raw | ConvertFrom-Json
      $expectedRuntime = [IO.Path]::GetFullPath($RepositoryPath).TrimEnd([IO.Path]::DirectorySeparatorChar)
      $stateRuntime = [IO.Path]::GetFullPath([string]$state.runtimePath).TrimEnd([IO.Path]::DirectorySeparatorChar)
      $stateLoader = [IO.Path]::GetFullPath([string]$state.loaderPath)
      $expectedLoader = [IO.Path]::GetFullPath((Join-Path $RepositoryPath 'UEEF-LOADER.md'))
      $checksPass = $state.requiredChecks -and !(@($state.requiredChecks.psobject.Properties | Where-Object { $_.Value -ne $true }).Count)
      if ($state.requireAgents -ne $true) { $agentsPass = $true }
      $loaderHashPass = ![string]::IsNullOrWhiteSpace([string]$state.runtimeLoaderSha256) -and (Get-FileHash -LiteralPath $expectedLoader -Algorithm SHA256).Hash -ceq ([string]$state.runtimeLoaderSha256).ToUpperInvariant()
      $activeStatePass = $state.active -eq $true -and $state.version -eq $version -and $state.agentRoutingContractVersion -eq 4 -and $state.reasoningCeiling -eq 'proportional' -and $stateRuntime -eq $expectedRuntime -and $stateLoader -eq $expectedLoader -and $loaderHashPass -and $checksPass
    } catch { $activeStatePass = $false }
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
$sourceRevisionStatus = "SKIPPED"
if (!$SkipRuntimeDrift -and $isManagedRuntime -and (Test-Item $activeStatePath)) {
  try {
    $stateForDrift = Get-Content -LiteralPath $activeStatePath -Raw | ConvertFrom-Json
    $sourceForDrift = [string]$stateForDrift.sourceRepositoryPath
    if (![string]::IsNullOrWhiteSpace($sourceForDrift) -and (Test-Item $sourceForDrift)) {
      . (Join-Path $RepositoryPath 'scripts\runtime-file-policy.ps1')
      $runtimeDriftPass = !(@(Get-UeefRuntimeDriftMismatches -SourcePath $sourceForDrift -RuntimePath $RepositoryPath -ExpectedLoaderHash ([string]$stateForDrift.runtimeLoaderSha256)).Count)
      $runtimeDriftStatus = if ($runtimeDriftPass) { "PASS" } else { "FAIL" }
      $recordedSourceCommit = [string]$stateForDrift.sourceCommit
      $currentSourceCommit = ''
      try { $currentSourceCommit = (git -C $sourceForDrift rev-parse HEAD 2>$null | Select-Object -First 1).Trim() } catch { $currentSourceCommit = '' }
      if ($recordedSourceCommit -and $recordedSourceCommit -ne 'UNKNOWN' -and $currentSourceCommit) {
        $sourceRevisionStatus = if ($recordedSourceCommit -eq $currentSourceCommit) { 'PASS' } else { 'WARN_OUTDATED' }
      }
    }
  } catch {
    $runtimeDriftPass = $false
    $runtimeDriftStatus = "FAIL"
  }
}
$markdownCount = if ($repoExists) { (Get-ChildItem -LiteralPath $RepositoryPath -Recurse -Filter *.md -File | Where-Object { $_.FullName -notmatch "\\.git\\" }).Count } else { 0 }
$globalExists = Test-Item $GlobalPath
$loaderCandidates = @()
if ($globalExists) {
  $loaderCandidates = Get-ChildItem -LiteralPath $GlobalPath -Recurse -Filter "UEEF-LOADER.md" -File -ErrorAction SilentlyContinue
}
$globalLoaderStatus = if (!$globalExists) { "UNKNOWN" } elseif ($loaderCandidates.Count -gt 0) { "PASS" } else { "FAIL" }
$installed = if ($repoExists -and $globalExists -and $loaderCandidates.Count -gt 0) { "YES" } else { "NO" }
$overall = if ($installed -eq "YES" -and $rootPass -and $corePass -and $masterLoaderPass -and $masterIndexPass -and $activationProofPass -and $activationGatePass -and $qualityGatesPass -and $validationPass -and $agentRoutingPass -and $agentsPass -and $activeStatePass -and $oldHomeAbsent -and $runtimeDriftPass) { "ACTIVE" } else { "INACTIVE" }

$statusResult = [ordered]@{
  schemaVersion = 1
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  version = $version
  installed = $installed
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
    agents = (PassFail $agentsPass)
    agentRouting = (PassFail $agentRoutingPass)
    activeState = (PassFail $activeStatePass)
    runtimeDrift = $runtimeDriftStatus
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
Write-Output "Core files: $(PassFail $corePass)"
Write-Output "Master loader: $(PassFail $masterLoaderPass)"
Write-Output "Master index: $(PassFail $masterIndexPass)"
Write-Output "Runtime activation proof: $(PassFail $activationProofPass)"
Write-Output "Activation gate: $(PassFail $activationGatePass)"
Write-Output "Quality gates: $(PassFail $qualityGatesPass)"
Write-Output "Markdown file count: $markdownCount"
Write-Output "Global loader: $globalLoaderStatus"
Write-Output "Codex AGENTS: $(PassFail $agentsPass)"
Write-Output "Agent routing contract: $(PassFail $agentRoutingPass)"
Write-Output "Active state: $(PassFail $activeStatePass)"
Write-Output "Runtime drift: $runtimeDriftStatus"
Write-Output "Runtime source revision: $sourceRevisionStatus"
if ($sourceRevisionStatus -eq 'WARN_OUTDATED') { Write-Output 'Required action: Sync the runtime before relying on updated intent or browser policies.' }
Write-Output "Old HOME .ueef absent: $(PassFail $oldHomeAbsent)"
if ($globalLoaderStatus -ne "PASS") {
  Write-Output "Required action: Run scripts/install-codex.ps1, scripts/install-cursor.ps1, or scripts/install-generic.ps1 from Codex with CODEX_HOME set, or set UEEF_GLOBAL_PATH to the Codex runtime path containing UEEF-LOADER.md."
}
Write-Output "Validation script: $(PassFail $validationPass)"
Write-Output "Overall: $overall"
