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
if ($Agent -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$' -or $Agent -in @('.', '..')) {
  throw "Unsafe agent name. Use one leaf name containing letters, numbers, dot, underscore, or hyphen."
}
$sourceCommit = "UNKNOWN"
try {
  $sourceCommit = (git -C $SourcePath rev-parse HEAD 2>$null)
  if (!$sourceCommit) { $sourceCommit = "UNKNOWN" }
} catch { $sourceCommit = "UNKNOWN" }
$versionText = Get-Content -LiteralPath (Join-Path $SourcePath "VERSION.md") -Raw
$versionMatch = [regex]::Match($versionText, '\b\d+\.\d+\.\d+\b')
$version = if ($versionMatch.Success) { $versionMatch.Value } else { throw "Could not read VERSION.md" }
New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null

$runtimeRoot = Join-Path $CodexHome "ueef"
$resolvedRuntimeRoot = [IO.Path]::GetFullPath($runtimeRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
$runtimePath = [IO.Path]::GetFullPath((Join-Path $resolvedRuntimeRoot $Agent))
$resolvedCodexHome = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $CodexHome).Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
$resolvedSource = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourcePath).Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
$runtimePrefix = $resolvedCodexHome + [IO.Path]::DirectorySeparatorChar
$runtimeRootPrefix = $resolvedRuntimeRoot + [IO.Path]::DirectorySeparatorChar
if (!$runtimePath.StartsWith($runtimeRootPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Parent $runtimePath) -ne $resolvedRuntimeRoot) {
  throw "Refusing unsafe runtime target: $runtimePath"
}
if ($resolvedSource -eq $resolvedCodexHome -or $resolvedSource.StartsWith($runtimePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Refusing to sync from inside CODEX_HOME: $resolvedSource"
}
if (Test-Path -LiteralPath $runtimePath) {
  $resolvedRuntime = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $runtimePath).Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
  if (!$resolvedRuntime.StartsWith($runtimePrefix, [System.StringComparison]::OrdinalIgnoreCase) -or $resolvedRuntime -eq $resolvedCodexHome) {
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
  "Version: $version",
  "",
  "Before every engineering task:",
  "0. Route every task through framework/58-agent-model-orchestration before substantial work.",
  "1. Load only these always-loaded modules: boot-loader, core-system.",
  "2. Reading UEEF-LOADER.md, AGENTS.md, status output, Master Loader, or Master Index does not make them Loaded modules.",
  "3. Use UEEF Master Loader from $master only to select relevant modules.",
  "4. Do not load the full framework unless the task is about UEEF audit, update, install, validation, or rebuild.",
  "5. Run UEEF Runtime Check.",
  "Run scripts/environment-bootstrap.ps1 on Windows or scripts/environment-bootstrap.sh on Unix before project inspection.",
  "At the beginning of every user turn, including an existing chat, re-read this loader and verify runtime version and status before selecting tools.",
  "Never rely on a loader or tool decision cached from an earlier turn.",
  "6. Select relevant UEEF modules for the task.",
  "7. Check MCPs, tools, connectors, scripts, and installed skills.",
  "8. Apply UI UX Pro Max whenever UI, UX, frontend, design, layout, accessibility, or visual polish is involved.",
  "9. Plan before editing non-trivial work.",
  "10. Apply UEEF Quality Gates before final answer.",
  "11. Include compact UEEF Verification with exactly these labels: UEEF, Loaded, Selected, Gates, Tools, Skills, UIUX, Status.",
  "12. The only valid Loaded line is: Loaded: boot-loader, core-system.",
  "13. If Loaded contains loader, UEEF-LOADER, AGENTS, master-loader, master-index, runtime-sequence, or activation-proof, the verification is invalid and must be rewritten before responding.",
  "",
  "Agent and model routing:",
  "- Classify every task T0 through T4 by scope, ambiguity, coupling, risk, and verification cost.",
  "- Use the lowest-cost capable model; current defaults are Luna for T1, Terra for T2, and Sol for T3/T4.",
  "- The lead agent is the valid single-agent topology for T0 and most T1 work. Spawn only when delegation has positive token or latency benefit.",
  "- Keep the critical path with the lead; give child agents bounded context and non-overlapping ownership.",
  "- Security, production, migration, destructive, privacy, payment, and incident work require frontier capability and risk-matched independent verification.",
  "- Escalate after scope growth, ambiguity, unexplained test failure, conflicting evidence, or discovered risk.",
  "- Reject risk score 3 without an explicit risk floor. Parallel agents require at least two independent workstreams.",
  "- Verify current agent and named-model availability before spawning or overriding; otherwise use the inherited model with unchanged gates.",
  "- The hard reasoning ceiling is medium for every model and agent. Never request high, xhigh, max, ultra, or an equivalent level above medium.",
  "- For T2 through T4, spawn a bounded child when agent tooling is available and a genuinely independent workstream has positive delegation benefit. Otherwise record exactly one reason: NO_INDEPENDENT_WORK, TOOL_UNAVAILABLE, or CRITICAL_PATH_ONLY.",
  "",
  "Design engineering skill routing:",
  "- Keep ui-ux-pro-max and impeccable as the general UI/UX baseline.",
  "- Add emil-design-eng for motion implementation and interaction polish.",
  "- Use review-animations for motion diffs, improve-animations for read-only audits and plans, animation-vocabulary for naming effects, and apple-design for gesture and spring work.",
  "- Select only skills whose triggers apply; do not load the full design suite by default.",
  "",
  "Delivery continuation:",
  "- An explicit request to expand scope, rebuild, migrate, or redesign is not a reason to suspend execution or wait for the user to resume.",
  "- Revise the plan and continue implementation and tests. Not ready to release blocks only a release claim, never requested coding work.",
  "- Use BLOCKED only for a real impasse: missing required access, unavailable mandatory dependency, unresolved destructive decision, or external state that prevents meaningful progress.",
  "",
  "Local command autonomy:",
  "- Run and reuse normal project commands and local development services without asking the user. A Codex command prompt is a platform confirmation, not an agent question or task blocker.",
  "- Reuse a healthy existing service before starting another long-running process.",
  "",
  "Browser hard stop:",
  "- Never use a connector-created Chrome window for a task that depends on the user's visible browser.",
  "- A `Chrome is being controlled by automated test software` banner, Codex-titled browser window, or unverified profile is a BLOCKED browser session.",
  "- Prefer visible Windows window control for the user's active browser. If the active window cannot be proven, stop without opening or controlling another browser.",
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
  "UEEF Version: $version",
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
  "At the beginning of every user turn, including an existing chat, re-read $loader and verify runtime version and status before selecting tools.",
  "Never rely on a loader or tool decision cached from an earlier turn.",
  "6. Select exact relevant UEEF modules for the task.",
  "7. Check available MCPs, tools, connectors, local scripts, and installed skills.",
  "8. Apply UI UX Pro Max whenever UI, UX, frontend, design, layout, accessibility, or visual polish is involved.",
  "9. Plan before editing non-trivial files.",
  "10. Apply UEEF Quality Gates before final response, including $activationGate.",
  "11. Include compact UEEF Verification with exactly these labels: UEEF, Loaded, Selected, Gates, Tools, Skills, UIUX, Status.",
  "12. The only valid Loaded line is exactly: Loaded: boot-loader, core-system.",
  "13. Reading or using UEEF-LOADER.md, AGENTS.md, master-loader, master-index, runtime-sequence, or activation-proof does not make them Loaded modules.",
  "14. If Loaded contains loader, UEEF-LOADER, AGENTS, master-loader, master-index, runtime-sequence, or activation-proof, rewrite the verification before final response.",
  "",
  "Agent and model routing:",
  "- Route every task through framework/58-agent-model-orchestration before substantial work.",
  "- Classify T0 through T4 and use the lowest-cost model that meets the complexity and risk floor.",
  "- Prefer Luna for bounded T1 child work, Terra for T2, and Sol for T3/T4 when explicit overrides are useful and available.",
  "- Do not spawn for appearance: T0 and most T1 work stay with the lead when delegation costs more tokens or time.",
  "- Keep immediate blockers and final integration with the lead; child tasks need bounded context, disjoint ownership, and explicit evidence.",
  "- T4 security, production, migration, destructive, privacy, payment, and incident work requires independent verification.",
  "- Reclassify and escalate after scope growth, ambiguity, unexplained failures, conflicts, or newly discovered risk.",
  "- Reject risk score 3 without an explicit risk floor. Parallel agents require at least two independent workstreams.",
  "- Verify current agent and named-model availability before spawning or overriding; otherwise use the inherited model with unchanged gates.",
  "- The hard reasoning ceiling is medium for every model and agent. Never request high, xhigh, max, ultra, or an equivalent level above medium.",
  "- For T2 through T4, spawn a bounded child when agent tooling is available and a genuinely independent workstream has positive delegation benefit. Otherwise record exactly one reason: NO_INDEPENDENT_WORK, TOOL_UNAVAILABLE, or CRITICAL_PATH_ONLY.",
  "",
  "Design engineering skill routing:",
  "- Keep ui-ux-pro-max and impeccable as the general UI/UX baseline.",
  "- Add emil-design-eng for motion implementation, easing, timing, transitions, and interaction polish.",
  "- Use review-animations for motion diffs and improve-animations for read-only codebase motion audits and plans.",
  "- Use animation-vocabulary only to name effects and apple-design for gesture, spring, momentum, interruptibility, sheets, drag/swipe, or Apple-style interaction work.",
  "- Select only skills whose triggers apply; do not load the full design suite by default.",
  "",
  "Delivery continuation:",
  "- An explicit request to expand scope, rebuild, migrate, or redesign is not a reason to suspend execution or wait for the user to resume.",
  "- Revise the plan and continue implementation and tests. Not ready to release blocks only a release claim, never requested coding work.",
  "- Use BLOCKED only for a real impasse: missing required access, unavailable mandatory dependency, unresolved destructive decision, or external state that prevents meaningful progress.",
  "",
  "Local command autonomy:",
  "- Run and reuse normal project commands and local development services without asking the user. A Codex command prompt is a platform confirmation, not an agent question or task blocker.",
  "- Reuse a healthy existing service before starting another long-running process.",
  "",
  "Browser hard stop:",
  "- Browser tasks must use the user's visible active browser window, not a connector-created Chrome window.",
  "- Automation banners, Codex-titled browser windows, and unverified profiles are BLOCKED.",
  "- Prefer visible Windows control for ordinary browser interaction. Use Chrome debugging only for debugging-specific capabilities such as DOM, console, network, or performance inspection.",
  "- Preserve the user's browser window state. Do not resize, emulate, move, restore, minimize, maximize, or alter full screen unless explicitly requested.",
  "- If the visible window cannot be proven, stop without opening another browser and use visible Windows control only after identity is verified.",
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

& (Join-Path $runtimePath "scripts\write-active-state.ps1") -RepositoryPath $runtimePath -CodexHome $CodexHome -RuntimeRoot $resolvedRuntimeRoot -Agent $Agent -RequireAgents -SourceRepositoryPath $SourcePath -SourceCommit $sourceCommit | Out-Null
Write-Output "UEEF runtime synced to $runtimePath"
Write-Output "Codex AGENTS updated at $agents"
