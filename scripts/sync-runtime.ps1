param(
  [string]$SourcePath = (Split-Path -Parent $PSScriptRoot),
  [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { "E:\shared folder\codex-home" }),
  [string]$Agent = "codex"
)
$ErrorActionPreference = "Stop"

function Write-Utf8File {
  param([string]$Path, [string[]]$Lines)
  [System.IO.File]::WriteAllLines($Path, $Lines, [System.Text.UTF8Encoding]::new($false))
}

if (!(Test-Path -LiteralPath $SourcePath)) { throw "SourcePath not found: $SourcePath" }
if (!(Test-Path -LiteralPath (Join-Path $SourcePath "framework"))) { throw "Source framework not found: $SourcePath" }
$sourceCommit = "UNKNOWN"
try {
  $sourceCommit = (git -C $SourcePath rev-parse HEAD 2>$null)
  if (!$sourceCommit) { $sourceCommit = "UNKNOWN" }
} catch { $sourceCommit = "UNKNOWN" }
New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null

$runtimeRoot = Join-Path $CodexHome "ueef"
$runtimePath = Join-Path $runtimeRoot $Agent
$resolvedCodexHome = (Resolve-Path -LiteralPath $CodexHome).Path
if (Test-Path -LiteralPath $runtimePath) {
  $resolvedRuntime = (Resolve-Path -LiteralPath $runtimePath).Path
  if (!$resolvedRuntime.StartsWith($resolvedCodexHome, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to replace unsafe runtime path: $resolvedRuntime"
  }
  Remove-Item -LiteralPath $resolvedRuntime -Recurse -Force
}
New-Item -ItemType Directory -Path $runtimePath -Force | Out-Null
Get-ChildItem -LiteralPath $SourcePath -Force | Where-Object { $_.Name -ne ".git" } | ForEach-Object {
  Copy-Item -LiteralPath $_.FullName -Destination $runtimePath -Recurse -Force
}

$core = Join-Path $runtimePath "framework\01-core\00-core-system.md"
$master = Join-Path $runtimePath "framework\01-core\01-master-loader.md"
$index = Join-Path $runtimePath "framework\01-core\02-master-index.md"
$masterIndex = Join-Path $runtimePath "framework\MASTER_INDEX.md"
$preflight = Join-Path $runtimePath "framework\01-core\12-ueef-required-preflight.md"
$activationGate = Join-Path $runtimePath "framework\27-quality-gates\16-ueef-activation-gate.md"
$loader = Join-Path $runtimePath "UEEF-LOADER.md"
$statusScript = Join-Path $runtimePath "scripts\ueef-status.ps1"

Write-Utf8File $loader @(
  "# UEEF Global Loader",
  "",
  "Runtime owner: Codex",
  "Global UEEF Path: $runtimeRoot",
  "Agent Runtime Path: $runtimePath",
  "Runtime source: self-contained copy inside Codex runtime",
  "Version: 1.0.0",
  "",
  "Before every engineering task:",
  "1. Load UEEF Boot Loader and Core System only as always-loaded modules.",
  "2. Use UEEF Master Loader from $master only to select relevant modules.",
  "3. Do not load the full framework unless the task is about UEEF audit, update, install, validation, or rebuild.",
  "4. Run UEEF Runtime Check.",
  "5. Select relevant UEEF modules for the task.",
  "6. Check MCPs, tools, connectors, scripts, and installed skills.",
  "7. Apply UI UX Pro Max whenever UI, UX, frontend, design, layout, accessibility, or visual polish is involved.",
  "8. Plan before editing non-trivial work.",
  "9. Apply UEEF Quality Gates before final answer.",
  "10. Include compact UEEF Verification with exactly these labels: UEEF, Loaded, Selected, Gates, Tools, Skills, UIUX, Status.",
  "",
  "If UEEF cannot be verified, report:",
  "",
  '```text',
  "UEEF: INACTIVE",
  "Reason:",
  "Required action:",
  '```',
  "",
  "When status is BLOCKED, do not edit project files."
)

$agents = Join-Path $CodexHome "AGENTS.md"
Write-Utf8File $agents @(
  "# Codex Global Runtime: UEEF",
  "",
  "This Codex installation must use the self-contained UEEF runtime before non-trivial engineering work.",
  "",
  "UEEF Active Runtime Path: $runtimePath",
  "UEEF Loader: $loader",
  "UEEF Status Script: $statusScript",
  "UEEF Version: 1.0.0",
  "",
  "## Mandatory Preflight",
  "",
  "Before every non-trivial engineering task:",
  "",
  "1. Read $loader.",
  "2. Load $core. This is the only core module loaded with the boot loader.",
  "3. Use $master as the selector for task-specific modules; do not report it under Loaded.",
  "4. Use $index and $masterIndex as references for selection; do not report them under Loaded.",
  "5. Run or mentally satisfy the UEEF Runtime Check from $preflight.",
  "6. Select exact relevant UEEF modules for the task.",
  "7. Check available MCPs, tools, connectors, local scripts, and installed skills.",
  "8. Apply UI UX Pro Max whenever UI, UX, frontend, design, layout, accessibility, or visual polish is involved.",
  "9. Plan before editing non-trivial files.",
  "10. Apply UEEF Quality Gates before final response, including $activationGate.",
  "11. Include compact UEEF Verification with exactly these labels: UEEF, Loaded, Selected, Gates, Tools, Skills, UIUX, Status. Loaded must be only: boot-loader, core-system.",
  "",
  "If UEEF cannot be verified, state:",
  "",
  '```text',
  "UEEF: INACTIVE",
  "Reason:",
  "Required action:",
  '```',
  "",
  "If the UEEF Runtime Check status is BLOCKED, do not edit project files.",
  "",
  "Do not use legacy verbose verification labels. Use only: UEEF, Loaded, Selected, Gates, Tools, Skills, UIUX, Status."
)

& (Join-Path $runtimePath "scripts\write-active-state.ps1") -RepositoryPath $runtimePath -CodexHome $CodexHome -SourceRepositoryPath $SourcePath -SourceCommit $sourceCommit | Out-Null
Write-Output "UEEF runtime synced to $runtimePath"
Write-Output "Codex AGENTS updated at $agents"
