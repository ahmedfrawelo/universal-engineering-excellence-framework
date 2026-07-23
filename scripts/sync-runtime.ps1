param(
  [string]$SourcePath = (Split-Path -Parent $PSScriptRoot),
  [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { "E:\shared folder\codex-home" }),
  [string]$Agent = "codex",
  [switch]$TestFailAfterState,
  [switch]$SkipOpenDesignSkills
)
$ErrorActionPreference = "Stop"

function Write-Utf8File {
  param([string]$Path, [string[]]$Lines)
  [System.IO.File]::WriteAllLines($Path, $Lines, [System.Text.UTF8Encoding]::new($false))
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
& (Join-Path $SourcePath 'scripts\validate-framework.ps1') -Root $SourcePath -SkipNestedTests | Out-Null
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
$activationGate = Join-Path $runtimePath "framework\27-quality-gates\16-ueef-activation-gate.md"
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
  "Before every engineering task:",
  "0. Route every task through framework/58-agent-model-orchestration before substantial work.",
  "1. Load only these always-loaded modules: boot-loader, core-system.",
  "2. Reading UEEF-LOADER.md, AGENTS.md, status output, Master Loader, or Master Index does not make them Loaded modules.",
  "3. Use UEEF Master Loader from $master only to select relevant modules.",
  "4. Do not load the full framework unless the task is about UEEF audit, update, install, validation, or rebuild.",
  "5. Run UEEF Runtime Check.",
  "For a self-contained T0/T1 answer or narrow change, start core-only and use tools only when they directly help the requested outcome. Run environment-bootstrap for non-trivial repository work or capability uncertainty; it is not a T0/T1 checklist.",
  "For non-trivial work or capability uncertainty, optionally run scripts/get-ueef-task-preflight.ps1. For multi-file changes, get-diff-impact.ps1 is heuristic only. Use project memory only for explicit local decisions, team-policy resolution only when a profile is declared, and evidence export before a high-risk closure or PR; these are proportional helpers, not a T0/T1 checklist.",
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
  "- Medium is the economical default. A route may request higher reasoning only for T3/T4 or high ambiguity, with recorded evidence; never lower the risk floor merely to avoid that escalation. If the platform selects a higher inherited level, UEEF does not prohibit it.",
  "- T1 code changes default to a single agent. Record Agent route: <tier> | Agent: spawned <id> or not spawned - NO_INDEPENDENT_WORK/CRITICAL_PATH_ONLY/TOOL_UNAVAILABLE; spawn only when independent work materially improves the requested outcome.",
  "",
  "Design engineering skill routing:",
  "- Keep ui-ux-pro-max and impeccable as the general UI/UX baseline.",
  "- Add design-brief to turn an ambiguous visual request into an explicit design specification before implementation.",
  "- Add frontend-design when building or materially polishing a production frontend interface.",
  "- Add emil-design-eng for motion implementation and interaction polish.",
  "- Use review-animations for motion diffs, improve-animations for read-only audits and plans, animation-vocabulary for naming effects, and apple-design for gesture and spring work.",
  "- Select only skills whose triggers apply; do not load the full design suite by default.",
  "",
  "Skill invocation protocol:",
  "- Before non-trivial work, evaluate named user-requested skills, installed skills, project-local skills, and UEEF packs.",
  "- Build the smallest useful skill chain for discovery, implementation, verification, and review.",
  "- Treat shortcut red flags as reroute triggers: missing skill check, untested fix, unsupported claim, partial verification, fake completion, or unbounded subagent work.",
  "- Use TDD or an equivalent evidence loop when behavior changes.",
  "",
  "Spec-driven development:",
  "- For broad, ambiguous, multi-file, high-impact, or durable work, make the specification the source of truth before implementation.",
  "- Separate what and why from how, resolve or document ambiguities, then translate requirements into a technical plan and traceable tasks.",
  "- Check consistency across specification, plan, tasks, code, tests, and final claims before completion.",
  "- If implementation reveals a requirement gap, update the specification or task list before continuing.",
  "",
  "File, folder, and size discipline:",
  "- Every new file must live under an owned feature, layer, package, route, docs, tests, scripts, generated-artifact, deployment, or configuration folder.",
  "- Reusable behavior, UI, validation, data access, formatting, configuration, and design logic must live in the existing shared/common/library owner and be imported by consumers.",
  "- Related files and recipes for one reusable component family must be grouped under one owned family folder with one canonical primitive and public entrypoint. Shared placement alone does not justify parallel implementations.",
  "- Before adding a shared component, search all shared roots and imports. Reuse it when complete, extend the existing owner when additions are needed, and create only when no compatible owner exists.",
  "- Before creating custom UI or behavior, inspect existing shared components, design tokens, layouts, registries, services, validators, API clients, utilities, stores, mappers, and pattern libraries.",
  "- Extend existing feature or shared owners before creating a parallel implementation. Create custom feature-local code only when it is genuinely single-use or explicitly isolated by product ownership.",
  "- Do not dump unrelated files into the project root or a generic mixed folder.",
  "- Do not create a standalone-file system unless it is a repository-standard entrypoint, documented configuration, one-off owned script, or explicit user-requested artifact.",
  "- Split files before they become mixed-responsibility sinks. Keep UI, data access, business rules, validation, transport, tests, generated content, and operational scripts in their owned areas.",
  "",
  "Backend and frontend performance:",
  "- Backend endpoints that serve UI data must consider server-side pagination, filtering, sorting, aggregation, projection, caching and invalidation, cancellation, concurrency, serialization cost, authorization cost, rate limits, and burst behavior.",
  "- Frontend routes must consider SSR, SSG, streaming, route-level pre-rendering, or server components when SEO, public content, first paint, slow client boot, or first-view data volume makes server rendering useful.",
  "- Do not force SSR for authenticated operational screens or stacks that intentionally use client rendering; record the reason when SSR is considered and skipped.",
  "- Prevent over-rendering end to end: frontend state, selectors, subscriptions, effects, memoization, virtualization, and component boundaries; backend over-fetching, over-serialization, repeated queries, noisy realtime broadcasts, broad cache invalidation, and unbounded recomputation.",
  "- Animations must be smooth, interruptible, reduced-motion aware, and compositor-friendly. Prefer transform and opacity, avoid layout-triggering animation, and prevent animation state from repainting unrelated UI or triggering avoidable backend refreshes.",
  "- Reconcile mutable remote state without page reload when freshness is required. Preserve route, shell, focus, scroll, filters, selection, and unsaved edits; verify authorization, ordering, gaps, reconnect, and burst performance.",
  "- Make an evidence-based eager, lazy, preload, prefetch, stream, or defer decision for every non-trivial load boundary. Do not create waterfalls, duplicate chunks, layout shift, inaccessible loading states, or first-request backend cold starts.",
  "- Inventory runtimes, dependencies, and upgrade opportunities only for explicit modernization/dependency work or when a T2+ task needs that evidence. Never turn a T0/T1 request into an autonomous inventory or upgrade.",
  "- Broad legacy refactoring requires repository and behavior baselines, characterization tests, hidden-reachability checks before deletion, reversible slices, compatibility and migration strategy, measured performance, rollout, and rollback.",
  "",
  "Response quality:",
  "- Answer the user's direct question first, then give concise evidence.",
  "- Do not claim perfection, completion, release, push, browser verification, or active runtime status without current evidence.",
  "- Keep final responses short and factual, with changed scope and validation when files were modified.",
  "- In Arabic or other RTL prose, every inline English word, identifier, product name, or short LTR phrase must be isolated for display readability. Do not insert hidden bidirectional control characters into code blocks, terminal commands, copyable file paths, JSON/YAML, source files, configuration, or repository content.",
  "",
  "Task scope discipline:",
  "- Work only on the requested task, its direct blockers, and regressions introduced by the current change.",
  "- Do not chase unrelated errors, warnings, tests, UI issues, backend endpoints, refactors, dependency warnings, or generated files.",
  "- If an unrelated pre-existing error appears, record it as unrelated, use narrower relevant validation when possible, and continue the requested work.",
  "- Broaden scope only when the user asks, when the unrelated issue directly prevents the requested task from being verified, or when the current change caused it.",
  "- Scope wins: if scope conflicts with continuation, delegation, autonomy, audits, or modernization, the user's requested task wins. Expand only on an explicit request or for a direct verification blocker.",
  "- Ask mode resolves only material ambiguity with one concise question or the smallest reversible assumption; Do mode executes the clear requested outcome and direct verification only.",
  "- Before non-trivial execution, show: Intent: <requested outcome> | Tier: <T0-T4> | Spawn: <no/yes and reason> | Browser: <no/yes and reason>.",
  "",
  "Large-project reuse:",
  "- For broad or unfamiliar repositories, run scripts/project-context-map.ps1 or scripts/project-context-map.sh, or an equivalent repository map, before implementation.",
  "- Discover module boundaries, aliases, barrel exports, public APIs, registries, package boundaries, shared folders, state stores, validators, service clients, and test utilities before implementation.",
  "- Use public imports/exports and project registries. Do not reach into private internals unless that is the established project convention.",
  "- When adding reusable capability, update the shared public export, tests, and at least one real consumer where project conventions expect it.",
  "",
  "Delivery continuation:",
  "- An explicit request to expand scope, rebuild, migrate, or redesign is not a reason to suspend execution or wait for the user to resume.",
  "- Revise the plan and continue implementation and tests. Not ready to release blocks only a release claim, never requested coding work.",
  "- Use BLOCKED only for a real impasse: missing required access, unavailable mandatory dependency, unresolved destructive decision, or external state that prevents meaningful progress.",
  "- Compile/test failures, API/facade/schema mismatches, save-contract bugs, incomplete wiring, and repeated failed patches are internal engineering work, never BLOCKED conditions. Replan, escalate, delegate bounded verification, and continue.",
  "- Missing screenshot evidence, pCloud screenshot delay, or task-local Chrome control degradation is not a valid BLOCKED condition when implementation, build, and non-visual tests can continue or have passed. Keep the task ACTIVE for more work, or report PARTIAL/visual-not-verified for status-only answers.",
  "- Repetition does not convert an internal bug into an external blocker. Mark a goal BLOCKED only for an external or user-only condition after no meaningful local work remains; never wait for the user merely to resume incomplete code.",
  "- Never pause an incomplete code path waiting for the user to resume it.",
  "- Stop when done: when a bounded requested outcome is complete, answer finally without optional expansion. Continue only explicit in-scope implementation that remains unfinished.",
  "",
  "Local command autonomy:",
  "- Run and reuse normal project commands and local development services without asking the user. A Codex command prompt is a platform confirmation, not an agent question or task blocker.",
  "- Reuse a healthy existing service before starting another long-running process.",
  "",
  "Browser hard stop (only for an explicitly required browser task):",
  "- HARD FAIL BEFORE ANY BROWSER TOOL: for a task tagged browser, run scripts/get-ueef-task-preflight.ps1 -Task <task> -TaskTag browser and resolve browserGate before selecting or calling any browser tool. The only allowed user-owned Chrome path is mcp__node_repl__js -> installed Chrome extension binding -> exact user.openTabs() object -> claimTab() -> claimed tab.playwright; if the gate is absent or unresolved, do not select a browser tool and do not open an alternate surface.",
  "- Never use a connector-created Chrome window for a task that depends on the user's visible browser.",
  "- Block a newly created automation/Codex window, temporary profile, or unverified profile. A control banner on the verified existing user tab is not an automatic block.",
  "- For Chrome, read the installed Chrome control skill and bootstrap its browser client only through mcp__node_repl__js, then use the extension binding, enumerate user.openTabs(), and claimTab() the verified user-owned tab.",
  "- Chrome readiness flow is mandatory before any Chrome-unavailable or BLOCKED claim: use the supported browser-client.mjs bootstrap, treat platform permission prompts as normal authorization, enumerate user.openTabs(), claimTab() the exact returned object, run scripts/repair-chrome-tab-ownership.ps1 for stale ownership, and finalize with chrome.tabs.finalize(...).",
  "- Browser work means the user's existing Chrome only - never a second browser, profile, context, Cursor/IDE Simple Browser, in-app browser, or connector-created window. For a user-owned Chrome task, never use directly exposed mcp__playwright__*, mcp__chrome_devtools__*, browser_* tools, browser.newContext, or browser.launch as substitutes. Playwright is allowed only through the claimed tab's tab.playwright API. An isolated/local browser test requires an explicit separate user request and never substitutes for the Chrome task. Use visible Windows control only when the Chrome plugin is independently unavailable and it can operate the same identified user-owned window and tab; otherwise STOP without opening a browser.",
  "- A transient Node REPL, browser-client, or extension bridge failure requires bootstrap-troubleshooting and chrome-troubleshooting plus retry on the same extension binding. Do not invent alternate import syntax or switch browser surfaces.",
  "- A task-local Node REPL or browser-client failure is THREAD_CONTROL_CHANNEL_DEGRADED, not proof that Chrome is unavailable. It cannot justify BLOCKED or asking the user to restart Chrome. Accept a trusted current VERIFIED_HANDOFF for the same user tab; request a fresh handoff after relevant code changes.",
  "- Only CHROME_EXTERNALLY_UNAVAILABLE can justify a browser-related BLOCKED state or asking the user to restart Chrome; a task-local control channel failure is not proof that Chrome is unavailable.",
  "- After the first local bridge failure, automatically seek a same-tab handoff and continue implementation. Do not ask the user to acknowledge, confirm, or type done for this failover. Do not expose retry counts, internal bridge errors, or a stopped-verification message; report only: Browser verification is being completed on your existing tab; implementation continues.",
  "- Before a browser-task turn ends, finalize claimed tabs through chrome.tabs.finalize(...) as the final browser action. This releases the user's tab for the next task without closing it and prevents stale ownership locks.",
  "- If claimTab() reports a stale browser-session owner, run scripts/repair-chrome-tab-ownership.ps1, reset the task browser binding, and reclaim the exact existing tab once. This is autonomous; do not ask another task or the user to intervene.",
  "- When browser or visual verification is required, keep the task active until the exact user-owned tab is claimed and verified. Build, tests, component reuse, source inspection, and structural equivalence cannot substitute for this gate or justify COMPLETE.",
  "- If visual verification is the only missing gate after implementation and tests passed, do not mark the goal BLOCKED only because a screenshot is pending. Report the implementation as verified by non-visual gates and keep visual verification explicitly pending unless the user's requested outcome was visual-only.",
  "- A minimized, background, or non-foreground user-owned Chrome window remains controllable through the extension and must not block or pause the goal. Defer only a visual operation that genuinely cannot run while minimized.",
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

& (Join-Path $stagingPath 'scripts\validate-framework.ps1') -Root $stagingPath -SkipNestedTests | Out-Null
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
try {
  if (Test-Path -LiteralPath $runtimePath) {
    Move-Item -LiteralPath $runtimePath -Destination $rollbackPath
  }
  Move-Item -LiteralPath $stagingPath -Destination $runtimePath
  $runtimeSwapped = $true

$managedAgentsLines = @(
  "# Codex Global Runtime: UEEF",
  "",
  "This Codex installation must use the self-contained UEEF runtime before non-trivial engineering work.",
  "",
  "UEEF Active Runtime Path: $runtimePath",
  "UEEF Loader: $loader",
  "UEEF Status Script: $statusScript",
  "UEEF Version: $version",
  "UEEF Display Metadata: $runtimePath\assets\ueef-display.json",
  "UEEF Skill/Icon Asset: $runtimePath\assets\ueef-skill-icon.svg",
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
  "For non-trivial work or capability uncertainty, optionally run scripts/get-ueef-task-preflight.ps1. For multi-file changes, get-diff-impact.ps1 is heuristic only. Use project memory only for explicit local decisions, team-policy resolution only when a profile is declared, and evidence export before a high-risk closure or PR; these are proportional helpers, not a T0/T1 checklist.",
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
  "- Medium is the economical default. A route may request higher reasoning only for T3/T4 or high ambiguity, with recorded evidence; never lower the risk floor merely to avoid that escalation. If the platform selects a higher inherited level, UEEF does not prohibit it.",
  "- T1 code changes default to a single agent. Record Agent route: <tier> | Agent: spawned <id> or not spawned - NO_INDEPENDENT_WORK/CRITICAL_PATH_ONLY/TOOL_UNAVAILABLE; spawn only when independent work materially improves the requested outcome.",
  "- Never claim UEEF routing or gates passed when required route evidence or child-agent evidence is missing.",
  "",
  "Design engineering skill routing:",
  "- Keep ui-ux-pro-max and impeccable as the general UI/UX baseline.",
  "- Add design-brief to turn an ambiguous visual request into an explicit design specification before implementation.",
  "- Add frontend-design when building or materially polishing a production frontend interface.",
  "- Add emil-design-eng for motion implementation, easing, timing, transitions, and interaction polish.",
  "- Use review-animations for motion diffs and improve-animations for read-only codebase motion audits and plans.",
  "- Use animation-vocabulary only to name effects and apple-design for gesture, spring, momentum, interruptibility, sheets, drag/swipe, or Apple-style interaction work.",
  "- Select only skills whose triggers apply; do not load the full design suite by default.",
  "",
  "Skill invocation protocol:",
  "- Before non-trivial work, evaluate named user-requested skills, installed skills, project-local skills, and UEEF packs.",
  "- Build the smallest useful skill chain for discovery, implementation, verification, and review.",
  "- Treat shortcut red flags as reroute triggers: missing skill check, untested fix, unsupported claim, partial verification, fake completion, or unbounded subagent work.",
  "- Use TDD or an equivalent evidence loop when behavior changes.",
  "",
  "Spec-driven development:",
  "- For broad, ambiguous, multi-file, high-impact, or durable work, make the specification the source of truth before implementation.",
  "- Separate what and why from how, resolve or document ambiguities, then translate requirements into a technical plan and traceable tasks.",
  "- Check consistency across specification, plan, tasks, code, tests, and final claims before completion.",
  "- If implementation reveals a requirement gap, update the specification or task list before continuing.",
  "",
  "File, folder, and size discipline:",
  "- Every new file must live under an owned feature, layer, package, route, docs, tests, scripts, generated-artifact, deployment, or configuration folder.",
  "- Reusable behavior, UI, validation, data access, formatting, configuration, and design logic must live in the existing shared/common/library owner and be imported by consumers.",
  "- Related files and recipes for one reusable component family must be grouped under one owned family folder with one canonical primitive and public entrypoint. Shared placement alone does not justify parallel implementations.",
  "- Before adding a shared component, search all shared roots and imports. Reuse it when complete, extend the existing owner when additions are needed, and create only when no compatible owner exists.",
  "- Before creating custom UI or behavior, inspect existing shared components, design tokens, layouts, registries, services, validators, API clients, utilities, stores, mappers, and pattern libraries.",
  "- Extend existing feature or shared owners before creating a parallel implementation. Create custom feature-local code only when it is genuinely single-use or explicitly isolated by product ownership.",
  "- Do not dump unrelated files into the project root or a generic mixed folder.",
  "- Do not create a standalone-file system unless it is a repository-standard entrypoint, documented configuration, one-off owned script, or explicit user-requested artifact.",
  "- Split files before they become mixed-responsibility sinks. Keep UI, data access, business rules, validation, transport, tests, generated content, and operational scripts in their owned areas.",
  "",
  "Backend and frontend performance:",
  "- Backend endpoints that serve UI data must consider server-side pagination, filtering, sorting, aggregation, projection, caching and invalidation, cancellation, concurrency, serialization cost, authorization cost, rate limits, and burst behavior.",
  "- Frontend routes must consider SSR, SSG, streaming, route-level pre-rendering, or server components when SEO, public content, first paint, slow client boot, or first-view data volume makes server rendering useful.",
  "- Do not force SSR for authenticated operational screens or stacks that intentionally use client rendering; record the reason when SSR is considered and skipped.",
  "- Prevent over-rendering end to end: frontend state, selectors, subscriptions, effects, memoization, virtualization, and component boundaries; backend over-fetching, over-serialization, repeated queries, noisy realtime broadcasts, broad cache invalidation, and unbounded recomputation.",
  "- Animations must be smooth, interruptible, reduced-motion aware, and compositor-friendly. Prefer transform and opacity, avoid layout-triggering animation, and prevent animation state from repainting unrelated UI or triggering avoidable backend refreshes.",
  "- Reconcile mutable remote state without page reload when freshness is required. Preserve route, shell, focus, scroll, filters, selection, and unsaved edits; verify authorization, ordering, gaps, reconnect, and burst performance.",
  "- Make an evidence-based eager, lazy, preload, prefetch, stream, or defer decision for every non-trivial load boundary. Do not create waterfalls, duplicate chunks, layout shift, inaccessible loading states, or first-request backend cold starts.",
  "- Inventory runtimes, dependencies, and upgrade opportunities only for explicit modernization/dependency work or when a T2+ task needs that evidence. Never turn a T0/T1 request into an autonomous inventory or upgrade.",
  "- Broad legacy refactoring requires repository and behavior baselines, characterization tests, hidden-reachability checks before deletion, reversible slices, compatibility and migration strategy, measured performance, rollout, and rollback.",
  "",
  "Response quality:",
  "- Answer the user's direct question first, then give concise evidence.",
  "- Do not claim perfection, completion, release, push, browser verification, or active runtime status without current evidence.",
  "- Keep final responses short and factual, with changed scope and validation when files were modified.",
  "- In Arabic or other RTL prose, every inline English word, identifier, product name, or short LTR phrase must be isolated for display readability. Do not insert hidden bidirectional control characters into code blocks, terminal commands, copyable file paths, JSON/YAML, source files, configuration, or repository content.",
  "",
  "Task scope discipline:",
  "- Work only on the requested task, its direct blockers, and regressions introduced by the current change.",
  "- Do not chase unrelated errors, warnings, tests, UI issues, backend endpoints, refactors, dependency warnings, or generated files.",
  "- If an unrelated pre-existing error appears, record it as unrelated, use narrower relevant validation when possible, and continue the requested work.",
  "- Broaden scope only when the user asks, when the unrelated issue directly prevents the requested task from being verified, or when the current change caused it.",
  "- Scope wins: if scope conflicts with continuation, delegation, autonomy, audits, or modernization, the user's requested task wins. Expand only on an explicit request or for a direct verification blocker.",
  "- Ask mode resolves only material ambiguity with one concise question or the smallest reversible assumption; Do mode executes the clear requested outcome and direct verification only.",
  "- Before non-trivial execution, show: Intent: <requested outcome> | Tier: <T0-T4> | Spawn: <no/yes and reason> | Browser: <no/yes and reason>.",
  "",
  "Large-project reuse:",
  "- For broad or unfamiliar repositories, run scripts/project-context-map.ps1 or scripts/project-context-map.sh, or an equivalent repository map, before implementation.",
  "- Discover module boundaries, aliases, barrel exports, public APIs, registries, package boundaries, shared folders, state stores, validators, service clients, and test utilities before implementation.",
  "- Use public imports/exports and project registries. Do not reach into private internals unless that is the established project convention.",
  "- When adding reusable capability, update the shared public export, tests, and at least one real consumer where project conventions expect it.",
  "",
  "Delivery continuation:",
  "- An explicit request to expand scope, rebuild, migrate, or redesign is not a reason to suspend execution or wait for the user to resume.",
  "- Revise the plan and continue implementation and tests. Not ready to release blocks only a release claim, never requested coding work.",
  "- Use BLOCKED only for a real impasse: missing required access, unavailable mandatory dependency, unresolved destructive decision, or external state that prevents meaningful progress.",
  "- Compile/test failures, API/facade/schema mismatches, save-contract bugs, incomplete wiring, and repeated failed patches are internal engineering work, never BLOCKED conditions. Replan, escalate, delegate bounded verification, and continue.",
  "- Missing screenshot evidence, pCloud screenshot delay, or task-local Chrome control degradation is not a valid BLOCKED condition when implementation, build, and non-visual tests can continue or have passed. Keep the task ACTIVE for more work, or report PARTIAL/visual-not-verified for status-only answers.",
  "- Repetition does not convert an internal bug into an external blocker. Mark a goal BLOCKED only for an external or user-only condition after no meaningful local work remains; never wait for the user merely to resume incomplete code.",
  "- Never pause an incomplete code path waiting for the user to resume it.",
  "- Stop when done: when a bounded requested outcome is complete, answer finally without optional expansion. Continue only explicit in-scope implementation that remains unfinished.",
  "",
  "Local command autonomy:",
  "- Run and reuse normal project commands and local development services without asking the user. A Codex command prompt is a platform confirmation, not an agent question or task blocker.",
  "- Reuse a healthy existing service before starting another long-running process.",
  "",
  "Browser hard stop (only for an explicitly required browser task):",
  "- HARD FAIL BEFORE ANY BROWSER TOOL: for a task tagged browser, run scripts/get-ueef-task-preflight.ps1 -Task <task> -TaskTag browser and resolve browserGate before selecting or calling any browser tool. The only allowed user-owned Chrome path is mcp__node_repl__js -> installed Chrome extension binding -> exact user.openTabs() object -> claimTab() -> claimed tab.playwright; if the gate is absent or unresolved, do not select a browser tool and do not open an alternate surface.",
  "- Browser work means the user's existing Chrome only - never a second browser, profile, context, Cursor/IDE Simple Browser, in-app browser, or connector-created window. Browser tasks must use the user's existing user-owned Chrome window and tab. Foreground or restored state is not required.",
  "- Newly created automation/Codex windows, temporary profiles, and unverified profiles are BLOCKED. A banner on a proven existing extension-claimed tab is not automatically blocked.",
  "- For Chrome, read the installed Chrome control skill and bootstrap its browser client only through mcp__node_repl__js, then use the extension binding, enumerate user.openTabs(), and claimTab() the verified user-owned tab. Extension attachment to an existing tab is allowed and must not be treated as a connector-created window.",
  "- Chrome readiness flow is mandatory before any Chrome-unavailable or BLOCKED claim: use the supported browser-client.mjs bootstrap, treat platform permission prompts as normal authorization, enumerate user.openTabs(), claimTab() the exact returned object, run scripts/repair-chrome-tab-ownership.ps1 for stale ownership, and finalize with chrome.tabs.finalize(...).",
  "- When work depends on an existing user-owned Chrome session, never use directly exposed mcp__playwright__*, mcp__chrome_devtools__*, browser_* tools, Cursor/IDE browser tools, browser.newContext, browser.launch, or in-app-browser tools as substitutes. Playwright is allowed only through the claimed tab's tab.playwright API. An isolated/local browser test requires an explicit separate user request and never substitutes for the Chrome task.",
  "- A transient Node REPL, browser-client, or extension bridge failure requires bootstrap-troubleshooting and chrome-troubleshooting plus retry on the same extension binding. Do not invent alternate import syntax or switch browser surfaces.",
  "- A task-local Node REPL or browser-client failure is THREAD_CONTROL_CHANNEL_DEGRADED, not proof that Chrome is unavailable. It cannot justify BLOCKED or asking the user to restart Chrome. Accept a trusted current VERIFIED_HANDOFF for the same user tab; request a fresh handoff after relevant code changes.",
  "- Only CHROME_EXTERNALLY_UNAVAILABLE can justify a browser-related BLOCKED state or asking the user to restart Chrome; a task-local control channel failure is not proof that Chrome is unavailable.",
  "- After the first local bridge failure, automatically seek a same-tab handoff and continue implementation. Do not ask the user to acknowledge, confirm, or type done for this failover. Do not expose retry counts, internal bridge errors, or a stopped-verification message; report only: Browser verification is being completed on your existing tab; implementation continues.",
  "- Before a browser-task turn ends, finalize claimed tabs through chrome.tabs.finalize(...) as the final browser action. This releases the user's tab for the next task without closing it and prevents stale ownership locks.",
  "- If claimTab() reports a stale browser-session owner, run scripts/repair-chrome-tab-ownership.ps1, reset the task browser binding, and reclaim the exact existing tab once. This is autonomous; do not ask another task or the user to intervene.",
  "- When browser or visual verification is required, keep the task active until the exact user-owned tab is claimed and verified. Build, tests, component reuse, source inspection, and structural equivalence cannot substitute for this gate or justify COMPLETE.",
  "- If visual verification is the only missing gate after implementation and tests passed, do not mark the goal BLOCKED only because a screenshot is pending. Report the implementation as verified by non-visual gates and keep visual verification explicitly pending unless the user's requested outcome was visual-only.",
  "- Preserve the user's browser window state. Do not resize, emulate, move, restore, minimize, maximize, or alter full screen unless explicitly requested.",
  "- A minimized, background, or non-foreground user-owned Chrome window remains controllable through the extension and must not pause the goal. Continue non-visual work if a visual-only check is unavailable.",
  "- If the user-owned tab cannot be proven, STOP without opening another browser. Use visible Windows control only when the Chrome plugin is independently unavailable and it can operate the same identified user-owned window and tab.",
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

# Keep the globally injected AGENTS block compact. Detailed guidance remains in the
# canonical runtime modules selected by the loader instead of being duplicated on every turn.
$managedAgentsLines = @(
  "# Codex Global Runtime: UEEF",
  "",
  "UEEF runtime: $runtimePath (version $version)",
  "Loader: $loader",
  "Status: $statusScript",
  "",
  "Before non-trivial work: read the loader, verify status, select task modules through $master, use bootstrap and gates only when proportional to the task, inspect only relevant skills/tools, and plan as needed.",
  "Optional helpers stay proportional: scripts/get-ueef-task-preflight.ps1 for uncertainty, scripts/get-diff-impact.ps1 for multi-file changes (heuristic only), project memory only for explicit local decisions, team policy only when declared, and evidence export before high-risk closure or a PR; not a T0/T1 checklist.",
  "Always load only boot-loader and core-system. The sole valid line is: Loaded: boot-loader, core-system.",
  "Final verification labels: UEEF, Loaded, Selected, Gates, Tools, Skills, UIUX, Status.",
  "",
  "Route every task through pack 58. T1 defaults to single-agent; spawn only for independent benefit or required independent verification, and record the route rationale.",
  "For UI work, apply ui-ux-pro-max and impeccable; add design-brief, frontend-design, or motion specialists only when their trigger matches.",
  "For broad or durable work, use the specification, plan, tasks, and evidence loop in pack 60.",
  "",
  "Stay within requested scope, preserve existing user work, and use the shared owner before creating a parallel implementation.",
  "Compile/test failures, API/facade/schema mismatches, save-contract bugs, incomplete wiring, and repeated failed patches are implementation work, not blockers.",
  "Repetition does not convert an internal bug into an external blocker; BLOCKED requires an external or user-only condition when no meaningful local work remains.",
  "Stop when done: answer finally once the bounded requested outcome is complete. When a goal is ACTIVE, continue only explicit unfinished in-scope implementation and read current goal status before finalizing longer goal work.",
  "Before non-trivial execution, state Intent, Tier, Spawn reason, and Browser reason in one short route line.",
  "",
  "HARD FAIL BEFORE ANY BROWSER TOOL: for a browser task, run scripts/get-ueef-task-preflight.ps1 -Task <task> -TaskTag browser and resolve browserGate before selecting or calling a browser tool. Use only mcp__node_repl__js -> extension binding -> exact user.openTabs() object -> claimTab() -> claimed tab.playwright; if unresolved, do not select a browser tool or open an alternate surface.",
  "For tasks requiring an existing Chrome session, visual verification, or authenticated site, use the verified user-owned tab through the Chrome plugin + Node REPL. Direct Playwright, Chrome DevTools, browser_* tools, Cursor/IDE Simple Browser, in-app browser tools, browser.newContext, and browser.launch are not substitutes. An isolated/local test requires an explicit separate user request, must not access or verify the user-owned task, and never opens as fallback.",
  "Preserve the user's browser window state and finalize claimed tabs when browser work ends.",
  "",
  "Canonical details live in the selected UEEF modules. Do not duplicate them in this managed block."
)

$managedStart = '<!-- UEEF-MANAGED:START -->'
$managedEnd = '<!-- UEEF-MANAGED:END -->'
$managedBlock = (@($managedStart) + $managedAgentsLines + @($managedEnd)) -join [Environment]::NewLine
$existingAgents = ''
if (Test-Path -LiteralPath $agents -PathType Leaf) {
  $existingAgents = Get-Content -LiteralPath $agents -Raw
  $agentsBackupRoot = Join-Path $resolvedRuntimeRoot 'backups\agents'
  New-Item -ItemType Directory -Path $agentsBackupRoot -Force | Out-Null
  $agentsBackup = Join-Path $agentsBackupRoot ('AGENTS-{0}-{1}.md' -f (Get-Date -Format yyyyMMddHHmmssfff), [guid]::NewGuid().ToString('N'))
  Copy-Item -LiteralPath $agents -Destination $agentsBackup -Force
}
if ($existingAgents -match '(?s)<!-- UEEF-MANAGED:START -->.*?<!-- UEEF-MANAGED:END -->') {
  $nextAgents = [regex]::Replace($existingAgents, '(?s)<!-- UEEF-MANAGED:START -->.*?<!-- UEEF-MANAGED:END -->', [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $managedBlock }, 1)
} elseif ($existingAgents.TrimStart().StartsWith('# Codex Global Runtime: UEEF', [StringComparison]::Ordinal)) {
  $nextAgents = $managedBlock
} elseif ([string]::IsNullOrWhiteSpace($existingAgents)) {
  $nextAgents = $managedBlock
} else {
  $nextAgents = $existingAgents.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $managedBlock
}
[IO.File]::WriteAllText($agents, $nextAgents.TrimEnd() + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))

if (!$SkipOpenDesignSkills) {
  & (Join-Path $runtimePath 'scripts\install-open-design-skills.ps1') -CodexHome $CodexHome | Out-Null
}

& (Join-Path $runtimePath "scripts\write-active-state.ps1") -RepositoryPath $runtimePath -CodexHome $CodexHome -RuntimeRoot $resolvedRuntimeRoot -Agent $Agent -RequireAgents -SourceRepositoryPath $SourcePath -SourceCommit $sourceCommit | Out-Null
if ($TestFailAfterState) { throw 'Injected test failure after active-state write.' }
if (Test-Path -LiteralPath $rollbackPath) { Remove-Item -LiteralPath $rollbackPath -Recurse -Force }
$runtimeSwapped = $false
if ($stateBackup -and (Test-Path -LiteralPath $stateBackup)) { Remove-Item -LiteralPath $stateBackup -Force -ErrorAction SilentlyContinue }
Write-Output "UEEF runtime synced to $runtimePath"
Write-Output "Codex AGENTS updated at $agents"
} catch {
  $failure = $_
  $rollbackFailure = $null
  try {
    if ($runtimeSwapped -and (Test-Path -LiteralPath $runtimePath)) {
      Remove-Item -LiteralPath $runtimePath -Recurse -Force
    }
    if (Test-Path -LiteralPath $rollbackPath) {
      Move-Item -LiteralPath $rollbackPath -Destination $runtimePath
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
  Get-ChildItem -LiteralPath $resolvedRuntimeRoot -Filter 'UEEF-ACTIVE.json.tmp.*' -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
  if ($stateBackup -and (Test-Path -LiteralPath $stateBackup)) { Remove-Item -LiteralPath $stateBackup -Force -ErrorAction SilentlyContinue }
  if (Test-Path -LiteralPath $stagingPath) { Remove-Item -LiteralPath $stagingPath -Recurse -Force }
  if ($rollbackFailure) { throw "Runtime sync failed and rollback was incomplete: $($rollbackFailure.Exception.Message)" }
  throw $failure
}
