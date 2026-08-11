param(
  [string]$SourcePath = (Split-Path -Parent $PSScriptRoot),
  [string]$CodexHome = '',
  [string]$Agent = "codex",
  [string]$BackupRoot = '',
  [string]$ManagedRequirementsPath = '',
  [switch]$TestFailAfterState,
  [switch]$TestFailRollbackCleanup,
  [switch]$InstallOpenDesignSkills,
  [switch]$SkipOpenDesignSkills,
  [switch]$SkipValidation,
  [switch]$Quiet
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'resolve-codex-home.ps1')
if ([string]::IsNullOrWhiteSpace($CodexHome)) { $CodexHome = Resolve-CodexHome }
$arabicBypass1 = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('2KrYrNin2YjYsiDYp9mE2KrYudmE2YrZhdin2Ko='))
$arabicBypass2 = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('2KfZhtiz2Ykg2KfZhNiq2LnZhNmK2YXYp9iq'))
$arabicBypass3 = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('2KrYrNin2YjYsiDYp9mE2YrZiCDYp9mKINin2Yog2KfZgQ=='))
$arabicBypassCodex = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('2KrYrNin2YjYsiBVRUVG'))
$arabicBypass4 = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('2KfYtNiq2LrZhCDYqNit2LHZitip'))
$arabicBypass5 = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('2KfYqNiq2YPYsSDYrtin2LHYrCDYp9mE2KXYt9in2LE='))
$arabicBypass6 = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('2KfYudmF2YQg2KjYr9mI2YYgVUVFRg=='))
$arabicStrict1 = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('2KfYsdis2Lkg2YTZhNmI2LbYuSDYp9mE2LXYp9ix2YU='))
$arabicStrict2 = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('2LHYrNmR2LkgVUVFRg=='))

function Write-Utf8File {
  param([string]$Path, [string[]]$Lines)
  [System.IO.File]::WriteAllLines($Path, $Lines, [System.Text.UTF8Encoding]::new($false))
}

function Invoke-FrameworkValidation {
  param([string]$Root, [switch]$QuietMode)
  if ($QuietMode) {
    $previousQuietValidation = $env:UEEF_QUIET_VALIDATION
    try {
      $env:UEEF_QUIET_VALIDATION = '1'
      & (Join-Path $Root 'scripts\validate-framework.ps1') -Root $Root -SkipNestedTests -Quiet *> $null
    } finally {
      if ($null -eq $previousQuietValidation) {
        Remove-Item Env:\UEEF_QUIET_VALIDATION -ErrorAction SilentlyContinue
      } else {
        $env:UEEF_QUIET_VALIDATION = $previousQuietValidation
      }
    }
  } else {
    & (Join-Path $Root 'scripts\validate-framework.ps1') -Root $Root -SkipNestedTests | Out-Null
  }
}

function Clear-StaleRuntimeTransactions {
  param([string]$RuntimeRoot, [TimeSpan]$MinimumAge = ([TimeSpan]::FromMinutes(10)))

  if (!(Test-Path -LiteralPath $RuntimeRoot -PathType Container)) { return }
  $rootItem = Get-Item -LiteralPath $RuntimeRoot -Force
  if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "Refusing to clean a reparse-point runtime root: $RuntimeRoot"
  }

  $cutoff = (Get-Date).Subtract($MinimumAge)
  foreach ($candidate in Get-ChildItem -LiteralPath $RuntimeRoot -Force -Directory) {
    if ($candidate.Name -notmatch '^\.(s|r)[0-9a-f]{8}$' -or $candidate.LastWriteTime -gt $cutoff) { continue }
    if (($candidate.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
    Remove-Item -LiteralPath $candidate.FullName -Recurse -Force
  }
}

. (Join-Path $PSScriptRoot 'runtime-file-policy.ps1')
. (Join-Path $PSScriptRoot 'managed-enforcement.ps1')

if (!(Test-Path -LiteralPath $SourcePath)) { throw "SourcePath not found: $SourcePath" }
if (!(Test-Path -LiteralPath (Join-Path $SourcePath "framework"))) { throw "Source framework not found: $SourcePath" }
if ($Agent -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$' -or $Agent -in @('.', '..')) {
  throw "Unsafe agent name. Use one leaf name containing letters, numbers, dot, underscore, or hyphen."
}
$sourceCommit = "UNKNOWN"
try {
  $sourceCommit = (git -c "safe.directory=$SourcePath" -C $SourcePath rev-parse HEAD 2>$null)
  if (!$sourceCommit) { $sourceCommit = "UNKNOWN" }
} catch { $sourceCommit = "UNKNOWN" }
$versionText = Get-Content -LiteralPath (Join-Path $SourcePath "VERSION.md") -Raw
$versionMatch = [regex]::Match($versionText, '\b\d+\.\d+\.\d+\b')
$version = if ($versionMatch.Success) { $versionMatch.Value } else { throw "Could not read VERSION.md" }
New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null
$codexHomeItem = Get-Item -LiteralPath $CodexHome -Force
if (($codexHomeItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Refusing reparse-point CODEX_HOME: $CodexHome" }

$runtimeRoot = Join-Path $CodexHome "ueef"
if (Test-Path -LiteralPath $runtimeRoot) {
  $runtimeRootItem = Get-Item -LiteralPath $runtimeRoot -Force
  if (($runtimeRootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Refusing reparse-point runtime root: $runtimeRoot" }
}
$resolvedRuntimeRoot = [IO.Path]::GetFullPath($runtimeRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
$runtimePath = [IO.Path]::GetFullPath((Join-Path $resolvedRuntimeRoot $Agent))
$resolvedCodexHome = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $CodexHome).Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
$requireManagedEnforcement = $Agent -ieq 'codex'
if ($requireManagedEnforcement -and [string]::IsNullOrWhiteSpace($ManagedRequirementsPath)) {
  $defaultCodexHome = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath (Resolve-CodexHome)).Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
  $ManagedRequirementsPath = if ($resolvedCodexHome -eq $defaultCodexHome) { Get-UeefManagedRequirementsPath -CodexHome $resolvedCodexHome } else { Join-Path $resolvedCodexHome 'managed-requirements\requirements.toml' }
}
$resolvedBackupRoot = Resolve-UeefBackupRoot -CodexHome $resolvedCodexHome -BackupRoot $BackupRoot
$resolvedSource = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourcePath).Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
$runtimePrefix = $resolvedCodexHome + [IO.Path]::DirectorySeparatorChar
$runtimeRootPrefix = $resolvedRuntimeRoot + [IO.Path]::DirectorySeparatorChar
if (!$runtimePath.StartsWith($runtimeRootPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Parent $runtimePath) -ne $resolvedRuntimeRoot) {
  throw "Refusing unsafe runtime target: $runtimePath"
}
if ($resolvedSource -eq $resolvedCodexHome -or
    $resolvedSource.StartsWith($runtimePrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
    $resolvedCodexHome.StartsWith($resolvedSource + [IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Refusing overlapping source and CODEX_HOME paths: $resolvedSource -> $resolvedCodexHome"
}
if (Test-Path -LiteralPath $runtimePath) {
  $resolvedRuntime = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $runtimePath).Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
  if (!$resolvedRuntime.StartsWith($runtimePrefix, [System.StringComparison]::OrdinalIgnoreCase) -or $resolvedRuntime -eq $resolvedCodexHome) {
    throw "Refusing to update unsafe runtime path: $resolvedRuntime"
  }
}
if (!$SkipValidation) {
  Invoke-FrameworkValidation -Root $SourcePath -QuietMode:$Quiet
}
$stagingPath = Join-Path $resolvedRuntimeRoot ('.s' + [guid]::NewGuid().ToString('N').Substring(0,8))
$rollbackPath = Join-Path $resolvedRuntimeRoot ('.r' + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $resolvedRuntimeRoot -Force | Out-Null
Clear-StaleRuntimeTransactions -RuntimeRoot $resolvedRuntimeRoot
Copy-UeefReleaseFiles -SourcePath $resolvedSource -DestinationPath $stagingPath

$core = Join-Path $runtimePath "framework\01-core\00-core-system.md"
$master = Join-Path $runtimePath "framework\01-core\01-master-loader.md"
$index = Join-Path $runtimePath "framework\01-core\02-master-index.md"
$masterIndex = Join-Path $runtimePath "framework\MASTER_INDEX.md"
$preflight = Join-Path $runtimePath "framework\01-core\12-ueef-required-preflight.md"
$activationGate = Join-Path $runtimePath "framework\12-delivery-quality/04-quality-gates\16-ueef-activation-gate.md"
$loader = Join-Path $runtimePath "UEEF-LOADER.md"
$stagingLoader = Join-Path $stagingPath "UEEF-LOADER.md"
$statusScript = Join-Path $runtimePath "scripts\ueef-status.ps1"

Write-Utf8File $stagingLoader @(
  "# UEEF Global Loader",
  "",
  "Runtime owner: Codex",
  "Global UEEF Path: $runtimeRoot",
  "Agent Runtime Path: $runtimePath",
  "Runtime source: self-contained copy inside Codex runtime",
  "Version: $version",
  "Skill/display metadata: assets/ueef-display.json",
  "Skill/display icon: assets/ueef-skill-icon.svg",
  "",
  "Boot contract:",
  "1. Read this loader once per task and run the runtime status check.",
  "2. Always load only boot-loader and core-system. Reading loaders, indexes, status, or activation files does not make them loaded modules.",
  "3. Select only task-relevant modules through $master; do not load the full framework except for UEEF audit, update, installation, validation, or rebuild.",
  "4. Route non-trivial work through framework/19-agent-workflow/01-model-orchestration; keep T0/T1 economical and normally single-agent.",
  "5. Select tools, skills, evidence, and review proportionally to the task tier and risk.",
  "",
  "Non-negotiable invariants:",
  "- Scope wins. Work only on the requested outcome, direct blockers, and regressions caused by the task. Stop when done.",
  "- Never claim completion, release, push, browser verification, or active runtime without current evidence.",
  "- Ask before destructive, irreversible, externally privileged, or materially ambiguous actions; preserve unrelated files and worktree changes.",
  "- Never bypass a managed-hook denial through another tool surface. Protect secrets, credentials, and private session state.",
  "- FREE-MODE may suspend repository ceremony, but never overrides system, developer, platform, security, privacy, authorization, destructive-action, browser, truthfulness, or scope constraints.",
  "",
  "Browser hard stop:",
  "- Browser control is only for an explicitly browser-required task. Use the installed Chrome control plugin on the user's existing profile and a dedicated task tab.",
  "- Never launch Playwright, Chrome DevTools, IDE Simple Browser, an in-app browser, a second browser/profile/session/context, or take over the working tab unless the canonical browser module explicitly permits an authorized fallback.",
  "- Run browser preflight and follow framework/18-runtime-operations/02-browser-session-control.",
  "",
  "Canonical owners:",
  "- Routing and model evidence: framework/19-agent-workflow/01-model-orchestration and config/model-routing-policy.json.",
  "- Lifecycle, scope, continuation, response, and FREE-MODE rules: framework/01-core.",
  "- T2+ evidence: config/enforcement-registry.json plus scripts/new-task-evidence.ps1 and scripts/validate-task-evidence.ps1.",
  "- T4 review: scripts/validate-fresh-review-evidence.ps1. Completion audit: scripts/validate-completion-audit.ps1 when selected.",
  "- Browser identity and recovery: framework/18-runtime-operations/02-browser-session-control.",
  "",
  "The only valid always-loaded report is:",
  "Loaded: boot-loader, core-system"
)

if (!$SkipValidation) {
  Invoke-FrameworkValidation -Root $stagingPath -QuietMode:$Quiet
}
$runtimeSwapped = $false
$agentsBackup = $null
$agents = Join-Path $CodexHome 'AGENTS.md'
$agentsItem = Get-Item -LiteralPath $agents -Force -ErrorAction SilentlyContinue
if ($agentsItem -and (($agentsItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw "Refusing reparse-point AGENTS file: $agents" }
$agentsExisted = Test-Path -LiteralPath $agents -PathType Leaf
$statePath = Join-Path $resolvedRuntimeRoot 'UEEF-ACTIVE.json'
$stateItem = Get-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue
if ($stateItem -and (($stateItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw "Refusing reparse-point active state: $statePath" }
$stateExisted = Test-Path -LiteralPath $statePath -PathType Leaf
$stateBackup = $null
if ($stateExisted) {
  $stateBackup = Join-Path $resolvedRuntimeRoot ('.state-' + [guid]::NewGuid().ToString('N') + '.json')
  Copy-Item -LiteralPath $statePath -Destination $stateBackup -Force
}
$managedHooksPath = Join-Path $resolvedRuntimeRoot 'managed-hooks'
$managedHooksExisted = $requireManagedEnforcement -and (Test-Path -LiteralPath $managedHooksPath -PathType Container)
$managedHooksBackup = $null
if ($managedHooksExisted) {
  $managedHooksBackup = Join-Path $resolvedRuntimeRoot ('.hooks-external-' + [guid]::NewGuid().ToString('N'))
  Copy-Item -LiteralPath $managedHooksPath -Destination $managedHooksBackup -Recurse
}
$managedRequirementsExisted = $requireManagedEnforcement -and (Test-Path -LiteralPath $ManagedRequirementsPath -PathType Leaf)
$managedRequirementsBefore = if ($managedRequirementsExisted) { [IO.File]::ReadAllText($ManagedRequirementsPath, [Text.Encoding]::UTF8) } else { $null }
$committed = $false
try {
  if (Test-Path -LiteralPath $runtimePath) {
    [IO.Directory]::Move($runtimePath, $rollbackPath)
  }
  [IO.Directory]::Move($stagingPath, $runtimePath)
  $runtimeSwapped = $true

# Keep the globally injected AGENTS block compact. Detailed guidance remains in the
# canonical runtime modules selected by the loader instead of being duplicated on every turn.
$managedAgentsLines = @(
  "# Codex Global Runtime: UEEF",
  "UEEF runtime: $runtimePath (version $version)",
  "Loader: $loader | Status: $statusScript",
  "",
  "Precedence: Scope wins; stop when done; T0/T1 stay single-agent; medium is the economical default, not a hard ceiling; read the loader once per task; browser control is explicit-task only.",
  "For non-trivial work: read loader, verify status, select modules/tools, record Intent/Tier/Spawn reason/Browser reason as route rationale.",
  "Always load only: Loaded: boot-loader, core-system. Final labels: UEEF, Loaded, Selected, Gates, Tools, Skills, UIUX, Status.",
  "T2+ gates use scripts/new-task-evidence.ps1 and scripts/validate-task-evidence.ps1 PASS; prose cannot pass.",
  "T4 auto-runs the selected fresh-review lane when eligible and requires scripts/validate-fresh-review-evidence.ps1 PASS before completion.",
  "Managed hooks enforce routing, protected paths, evidence, completion, progress, and goal closure. 100 percent means complete.",
  "",
  "Browser hard stop: For browser-required tasks, use the installed Chrome control plugin automatically on a dedicated task tab. Never launch Playwright, chrome-devtools, IDE Simple Browser, a second profile, or a new context; ask only for external missing access or authorized emergency fallback.",
  "",
  "Canonical details and gates live in the selected modules: $master. Do not duplicate them here."
)

$managedStart = '<!-- UEEF-MANAGED:START -->'
$managedEnd = '<!-- UEEF-MANAGED:END -->'
$managedBlock = (@($managedStart) + $managedAgentsLines + @($managedEnd)) -join [Environment]::NewLine
$existingAgents = ''
if (Test-Path -LiteralPath $agents -PathType Leaf) {
  $existingAgents = Get-Content -LiteralPath $agents -Raw
  $agentsBackupRoot = Join-Path $resolvedBackupRoot 'agents'
  New-Item -ItemType Directory -Path $agentsBackupRoot -Force | Out-Null
  $agentsBackup = Join-Path $agentsBackupRoot ('AGENTS-{0}-{1}.md' -f (Get-Date -Format yyyyMMddHHmmssfff), [guid]::NewGuid().ToString('N'))
  Copy-Item -LiteralPath $agents -Destination $agentsBackup -Force
}
if ($existingAgents -match '(?s)<!-- UEEF-MANAGED:START -->.*?<!-- UEEF-MANAGED:END -->') {
  $nextAgents = [regex]::Replace($existingAgents, '(?s)<!-- UEEF-MANAGED:START -->.*?<!-- UEEF-MANAGED:END -->', [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $managedBlock }, 1)
} elseif (![string]::IsNullOrWhiteSpace($existingAgents) -and $existingAgents.TrimStart().StartsWith('# Codex Global Runtime: UEEF', [StringComparison]::Ordinal)) {
  $nextAgents = $managedBlock
} elseif ([string]::IsNullOrWhiteSpace($existingAgents)) {
  $nextAgents = $managedBlock
} else {
  $nextAgents = $existingAgents.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $managedBlock
}
[IO.File]::WriteAllText($agents, $nextAgents.TrimEnd() + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))

if ($InstallOpenDesignSkills -and !$SkipOpenDesignSkills) {
  & (Join-Path $runtimePath 'scripts\install-open-design-skills.ps1') -CodexHome $CodexHome | Out-Null
}

$managedInstall = $null
if ($requireManagedEnforcement) {
  $managedInstall = Install-UeefManagedEnforcement -RuntimePath $runtimePath -RuntimeRoot $resolvedRuntimeRoot -RequirementsPath $ManagedRequirementsPath
}
$stateParameters = @{
  RepositoryPath = $runtimePath
  CodexHome = $CodexHome
  RuntimeRoot = $resolvedRuntimeRoot
  Agent = $Agent
  RequireAgents = $true
  SourceRepositoryPath = $resolvedSource
  SourceCommit = $sourceCommit
}
if ($requireManagedEnforcement) {
  $stateParameters.RequireManagedEnforcement = $true
  $stateParameters.ManagedRequirementsPath = $managedInstall.requirementsPath
  $stateParameters.ManagedHooksPath = $managedInstall.hooksPath
  $stateParameters.ManagedNodePath = $managedInstall.nodePath
}
if ($Quiet) { $stateParameters.Quiet = $true }
& (Join-Path $runtimePath "scripts\write-active-state.ps1") @stateParameters | Out-Null
if ($TestFailAfterState) { throw 'Injected test failure after active-state write.' }
$runtimeSwapped = $false
$committed = $true
$committedRollbackPath = $rollbackPath
$rollbackPath = $null
if (Test-Path -LiteralPath $committedRollbackPath) {
  try {
    if ($TestFailRollbackCleanup) { throw 'Injected rollback cleanup failure.' }
    Remove-Item -LiteralPath $committedRollbackPath -Recurse -Force -ErrorAction Stop
  }
  catch { Write-Warning "Runtime was committed, but old rollback cleanup is pending: $committedRollbackPath" }
}
if ($stateBackup -and (Test-Path -LiteralPath $stateBackup)) { Remove-Item -LiteralPath $stateBackup -Force -ErrorAction SilentlyContinue }
if ($managedHooksBackup -and (Test-Path -LiteralPath $managedHooksBackup)) { Remove-Item -LiteralPath $managedHooksBackup -Recurse -Force -ErrorAction SilentlyContinue }
Write-Output "UEEF runtime synced to $runtimePath"
Write-Output "Codex AGENTS updated at $agents"
if ($requireManagedEnforcement) { Write-Output "Codex managed enforcement installed at $managedHooksPath" }
} catch {
  $failure = $_
  if ($committed) {
    [Console]::Error.WriteLine("UEEF runtime is committed; skipped obsolete rollback after a post-commit error: $($failure.Exception.Message)")
    return
  }
  $rollbackFailure = $null
  try {
    if ($runtimeSwapped -and (Test-Path -LiteralPath $runtimePath)) {
      Remove-Item -LiteralPath $runtimePath -Recurse -Force
    }
    if ($rollbackPath -and (Test-Path -LiteralPath $rollbackPath)) {
      [IO.Directory]::Move($rollbackPath, $runtimePath)
    }
  } catch { $rollbackFailure = $_ }
  if ($agentsBackup -and (Test-Path -LiteralPath $agentsBackup)) {
    Copy-Item -LiteralPath $agentsBackup -Destination $agents -Force
  } elseif (!$agentsExisted -and (Test-Path -LiteralPath $agents)) {
    Remove-Item -LiteralPath $agents -Force
  }
  if ($stateExisted -and $stateBackup -and (Test-Path -LiteralPath $stateBackup)) {
    Copy-Item -LiteralPath $stateBackup -Destination $statePath -Force
  } elseif (!$stateExisted -and (Test-Path -LiteralPath $statePath)) {
    Remove-Item -LiteralPath $statePath -Force
  }
  if ($requireManagedEnforcement) {
    if (Test-Path -LiteralPath $managedHooksPath) { Remove-Item -LiteralPath $managedHooksPath -Recurse -Force }
    if ($managedHooksExisted -and $managedHooksBackup -and (Test-Path -LiteralPath $managedHooksBackup)) { Move-Item -LiteralPath $managedHooksBackup -Destination $managedHooksPath }
    if ($managedRequirementsExisted) {
      New-Item -ItemType Directory -Path (Split-Path -Parent $ManagedRequirementsPath) -Force | Out-Null
      [IO.File]::WriteAllText($ManagedRequirementsPath, $managedRequirementsBefore, [Text.UTF8Encoding]::new($false))
    } elseif (Test-Path -LiteralPath $ManagedRequirementsPath) { Remove-Item -LiteralPath $ManagedRequirementsPath -Force }
  }
  Get-ChildItem -LiteralPath $resolvedRuntimeRoot -Filter 'UEEF-ACTIVE.json.tmp.*' -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
  if ($stateBackup -and (Test-Path -LiteralPath $stateBackup)) { Remove-Item -LiteralPath $stateBackup -Force -ErrorAction SilentlyContinue }
  if ($managedHooksBackup -and (Test-Path -LiteralPath $managedHooksBackup)) { Remove-Item -LiteralPath $managedHooksBackup -Recurse -Force -ErrorAction SilentlyContinue }
  if (Test-Path -LiteralPath $stagingPath) { Remove-Item -LiteralPath $stagingPath -Recurse -Force }
  if ($rollbackFailure) { throw "Runtime sync failed and rollback was incomplete: $($rollbackFailure.Exception.Message)" }
  throw $failure
}
