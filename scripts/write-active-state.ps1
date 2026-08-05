param(
  [string]$RepositoryPath = (Split-Path -Parent $PSScriptRoot),
  [string]$CodexHome = '',
  [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')][string]$Agent = 'codex',
  [string]$RuntimeRoot = '',
  [switch]$RequireAgents,
  [switch]$RequireManagedEnforcement,
  [string]$ManagedRequirementsPath = '',
  [string]$ManagedHooksPath = '',
  [string]$ManagedNodePath = '',
  [string]$SourceRepositoryPath = $RepositoryPath,
  [string]$SourceCommit = "",
  [switch]$Quiet
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'resolve-codex-home.ps1')
if ([string]::IsNullOrWhiteSpace($CodexHome)) { $CodexHome = Resolve-CodexHome }
if ($Agent -ieq 'codex' -and !$RequireAgents) {
  throw 'Refusing to write an ACTIVE Codex state without -RequireAgents. Use scripts/install-codex.ps1 or scripts/sync-runtime.ps1.'
}
if ($Agent -ieq 'codex' -and !$RequireManagedEnforcement) {
  throw 'Refusing to write an ACTIVE Codex state without -RequireManagedEnforcement. Use scripts/sync-runtime.ps1.'
}
if ($RequireManagedEnforcement -and ([string]::IsNullOrWhiteSpace($ManagedRequirementsPath) -or [string]::IsNullOrWhiteSpace($ManagedHooksPath) -or [string]::IsNullOrWhiteSpace($ManagedNodePath))) {
  throw 'Managed enforcement requires requirements, hooks, and Node paths.'
}

$runtimeRoot = if ([string]::IsNullOrWhiteSpace($RuntimeRoot)) { Join-Path $CodexHome "ueef" } else { $RuntimeRoot }
$runtimePath = Join-Path $runtimeRoot $Agent
$loader = Join-Path $runtimePath "UEEF-LOADER.md"
$agents = Join-Path $CodexHome "AGENTS.md"
$versionPath = Join-Path $RepositoryPath "VERSION.md"
$version = "UNKNOWN"
if (Test-Path -LiteralPath $versionPath) {
  $versionText = Get-Content -LiteralPath $versionPath -Raw
  $match = [regex]::Match($versionText, "version:\s*([0-9]+\.[0-9]+\.[0-9]+)", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if ($match.Success) { $version = $match.Groups[1].Value }
}
$commit = $SourceCommit
if ([string]::IsNullOrWhiteSpace($commit)) {
  $commit = "UNKNOWN"
  try {
    $commit = (git -c "safe.directory=$SourceRepositoryPath" -C $SourceRepositoryPath rev-parse HEAD 2>$null)
    if (!$commit) { $commit = "UNKNOWN" }
  } catch { $commit = "UNKNOWN" }
}

$requiredChecks = [ordered]@{
  loader = (Test-Path -LiteralPath $loader)
  agents = (!$RequireAgents -or (Test-Path -LiteralPath $agents))
  coreSystem = (Test-Path -LiteralPath (Join-Path $RepositoryPath "framework/01-core/00-core-system.md"))
  masterLoader = (Test-Path -LiteralPath (Join-Path $RepositoryPath "framework/01-core/01-master-loader.md"))
  masterIndex = (Test-Path -LiteralPath (Join-Path $RepositoryPath "framework/01-core/02-master-index.md"))
  activationGate = (Test-Path -LiteralPath (Join-Path $RepositoryPath "framework/27-quality-gates/16-ueef-activation-gate.md"))
  statusScript = (Test-Path -LiteralPath (Join-Path $RepositoryPath "scripts/ueef-status.ps1"))
  managedRequirements = (!$RequireManagedEnforcement -or ((Test-Path -LiteralPath $ManagedRequirementsPath -PathType Leaf) -and [IO.File]::ReadAllText($ManagedRequirementsPath, [Text.Encoding]::UTF8).StartsWith('# UEEF-MANAGED-REQUIREMENTS', [StringComparison]::Ordinal)))
  managedHooks = (!$RequireManagedEnforcement -or ((@('ueef-codex-hook.mjs','record-ueef-route.mjs','ueef-hook-common.mjs','codex-enforcement-policy.json') | Where-Object { !(Test-Path -LiteralPath (Join-Path $ManagedHooksPath $_) -PathType Leaf) }).Count -eq 0 -and (Test-Path -LiteralPath $ManagedNodePath -PathType Leaf)))
}
$checksPass = !(@($requiredChecks.GetEnumerator() | Where-Object { $_.Value -ne $true }).Count)
if (!$checksPass) {
  $failed = @($requiredChecks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object Key)
  throw "Refusing to write ACTIVE state; required checks failed: $($failed -join ', ')"
}
$validator = Join-Path $RepositoryPath 'scripts\validate-framework.ps1'
if (!(Test-Path -LiteralPath $validator -PathType Leaf)) { throw "Refusing to write ACTIVE state without validator: $validator" }
if ($Quiet) {
  $previousQuietValidation = $env:UEEF_QUIET_VALIDATION
  try {
    $env:UEEF_QUIET_VALIDATION = '1'
    & $validator -Root $RepositoryPath -SkipNestedTests -Quiet *> $null
  } finally {
    if ($null -eq $previousQuietValidation) {
      Remove-Item Env:\UEEF_QUIET_VALIDATION -ErrorAction SilentlyContinue
    } else {
      $env:UEEF_QUIET_VALIDATION = $previousQuietValidation
    }
  }
} else {
  & $validator -Root $RepositoryPath -SkipNestedTests | Out-Null
}

$state = [ordered]@{
  active = $checksPass
  agentRoutingContractVersion = 4
  reasoningCeiling = 'proportional'
  version = $version
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
  codexHome = $CodexHome
  runtimeRoot = $runtimeRoot
  runtimePath = $runtimePath
  agent = $Agent
  repositoryPath = $RepositoryPath
  sourceRepositoryPath = $SourceRepositoryPath
  sourceCommit = $commit
  loaderPath = $loader
  runtimeLoaderSha256 = (Get-FileHash -LiteralPath $loader -Algorithm SHA256).Hash.ToLowerInvariant()
  agentsPath = $agents
  requireAgents = $RequireAgents.IsPresent
  managedEnforcement = if ($RequireManagedEnforcement) {
    [ordered]@{
      required = $true
      contractVersion = 1
      requirementsPath = [IO.Path]::GetFullPath($ManagedRequirementsPath)
      requirementsSha256 = (Get-FileHash -LiteralPath $ManagedRequirementsPath -Algorithm SHA256).Hash.ToLowerInvariant()
      hooksPath = [IO.Path]::GetFullPath($ManagedHooksPath)
      nodePath = [IO.Path]::GetFullPath($ManagedNodePath)
      nodeSha256 = (Get-FileHash -LiteralPath $ManagedNodePath -Algorithm SHA256).Hash.ToLowerInvariant()
      hookFiles = @('ueef-codex-hook.mjs','record-ueef-route.mjs','ueef-hook-common.mjs','codex-enforcement-policy.json') | ForEach-Object {
        $hookPath = Join-Path $ManagedHooksPath $_
        [ordered]@{relativePath=$_;sha256=(Get-FileHash -LiteralPath $hookPath -Algorithm SHA256).Hash.ToLowerInvariant()}
      }
    }
  } else { [ordered]@{required=$false;contractVersion=1} }
  oldHomeUeefExists = (Test-Path -LiteralPath (Join-Path $HOME ".ueef"))
  requiredChecks = $requiredChecks
}
$statePath = Join-Path $runtimeRoot "UEEF-ACTIVE.json"
New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
$stateItem = Get-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue
if ($stateItem -and (($stateItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw "Refusing reparse-point active state: $statePath" }
$temporaryState = "$statePath.tmp.$([guid]::NewGuid().ToString('N'))"
[IO.File]::WriteAllText($temporaryState, ($state | ConvertTo-Json -Depth 8) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
Move-Item -LiteralPath $temporaryState -Destination $statePath -Force
Write-Output "UEEF active state written: $statePath"
