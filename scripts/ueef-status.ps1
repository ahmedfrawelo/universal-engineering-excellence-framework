param(
  [string]$RepositoryPath = (Split-Path -Parent $PSScriptRoot),
  [string]$GlobalPath = $(if ($env:UEEF_GLOBAL_PATH) { $env:UEEF_GLOBAL_PATH } elseif ($env:CODEX_HOME) { Join-Path $env:CODEX_HOME "ueef" } else { Join-Path (Split-Path -Parent $RepositoryPath) "ueef-runtime" })
)
$ErrorActionPreference = "Stop"

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
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Split-Path -Parent $GlobalPath }
$agentsPath = Join-Path $codexHome "AGENTS.md"
$isCodexRuntime = (Split-Path -Leaf $RepositoryPath) -eq "codex"
if ($isCodexRuntime) {
  $agentsPass = (Test-Item $agentsPath) -and ((Get-Content -LiteralPath $agentsPath -Raw) -match [regex]::Escape($GlobalPath))
  $activeStatePath = Join-Path $GlobalPath "UEEF-ACTIVE.json"
  $activeStatePass = Test-Item $activeStatePath
} else {
  $agentsPass = $true
  $activeStatePath = Join-Path $GlobalPath "UEEF-ACTIVE.json"
  $activeStatePass = $true
}
$oldHomePath = Join-Path $HOME ".ueef"
$oldHomeAbsent = !(Test-Item $oldHomePath)
$markdownCount = if ($repoExists) { (Get-ChildItem -LiteralPath $RepositoryPath -Recurse -Filter *.md -File | Where-Object { $_.FullName -notmatch "\\.git\\" }).Count } else { 0 }
$globalExists = Test-Item $GlobalPath
$loaderCandidates = @()
if ($globalExists) {
  $loaderCandidates = Get-ChildItem -LiteralPath $GlobalPath -Recurse -Filter "UEEF-LOADER.md" -File -ErrorAction SilentlyContinue
}
$globalLoaderStatus = if (!$globalExists) { "UNKNOWN" } elseif ($loaderCandidates.Count -gt 0) { "PASS" } else { "FAIL" }
$installed = if ($repoExists -and $globalExists -and $loaderCandidates.Count -gt 0) { "YES" } else { "NO" }
$overall = if ($installed -eq "YES" -and $rootPass -and $corePass -and $masterLoaderPass -and $masterIndexPass -and $activationProofPass -and $activationGatePass -and $qualityGatesPass -and $validationPass -and $agentsPass -and $activeStatePass -and $oldHomeAbsent) { "ACTIVE" } else { "INACTIVE" }

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
Write-Output "Active state: $(PassFail $activeStatePass)"
Write-Output "Old HOME .ueef absent: $(PassFail $oldHomeAbsent)"
if ($globalLoaderStatus -ne "PASS") {
  Write-Output "Required action: Run scripts/install-codex.ps1, scripts/install-cursor.ps1, or scripts/install-generic.ps1 from Codex with CODEX_HOME set, or set UEEF_GLOBAL_PATH to the Codex runtime path containing UEEF-LOADER.md."
}
Write-Output "Validation script: $(PassFail $validationPass)"
Write-Output "Overall: $overall"
