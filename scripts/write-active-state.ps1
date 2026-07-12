param(
  [string]$RepositoryPath = (Split-Path -Parent $PSScriptRoot),
  [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { "E:\shared folder\codex-home" }),
  [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')][string]$Agent = 'codex',
  [string]$RuntimeRoot = '',
  [switch]$RequireAgents,
  [string]$SourceRepositoryPath = $RepositoryPath,
  [string]$SourceCommit = ""
)
$ErrorActionPreference = "Stop"

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
    $commit = (git -C $SourceRepositoryPath rev-parse HEAD 2>$null)
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
}
$checksPass = !(@($requiredChecks.GetEnumerator() | Where-Object { $_.Value -ne $true }).Count)

$state = [ordered]@{
  active = $checksPass
  agentRoutingContractVersion = 3
  reasoningCeiling = 'medium'
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
  agentsPath = $agents
  requireAgents = $RequireAgents.IsPresent
  oldHomeUeefExists = (Test-Path -LiteralPath (Join-Path $HOME ".ueef"))
  requiredChecks = $requiredChecks
}
$statePath = Join-Path $runtimeRoot "UEEF-ACTIVE.json"
New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
$state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $statePath -Encoding utf8
Write-Output "UEEF active state written: $statePath"
