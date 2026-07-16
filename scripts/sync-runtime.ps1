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
    throw "Refusing to update unsafe runtime path: $resolvedRuntime"
  }
}
New-Item -ItemType Directory -Path $runtimePath -Force | Out-Null
# Keep the active runtime intact while tasks can have imported files from it.
# Copying source updates in place avoids invalidating a live Node REPL/browser client.
Get-ChildItem -LiteralPath $SourcePath -Force | Where-Object { $_.Name -ne ".git" } | ForEach-Object {
  Copy-Item -LiteralPath $_.FullName -Destination $runtimePath -Recurse -Force
}

$ownedRuntimeDirs = @('framework','scripts','docs','examples','tools','assets')
foreach ($ownedDir in $ownedRuntimeDirs) {
  $sourceOwnedDir = Join-Path $SourcePath $ownedDir
  $runtimeOwnedDir = Join-Path $runtimePath $ownedDir
  if (!(Test-Path -LiteralPath $runtimeOwnedDir)) { continue }

  Get-ChildItem -LiteralPath $runtimeOwnedDir -Recurse -Force | Sort-Object FullName -Descending | ForEach-Object {
    $relativeOwnedPath = $_.FullName.Substring($runtimeOwnedDir.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $sourceEquivalent = Join-Path $sourceOwnedDir $relativeOwnedPath
    if (!(Test-Path -LiteralPath $sourceEquivalent)) {
      Remove-Item -LiteralPath $_.FullName -Recurse -Force
    }
  }
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
  "- Every non-trivial T1-T4 code-changing task must spawn at least one bounded child when agent tooling is callable. Before the first project command or edit, show Agent route: <tier> | Agent: spawned <id or nickname>. The only valid no-spawn reason for code-changing work is TOOL_UNAVAILABLE.",
  "",
  "Design engineering skill routing:",
  "- Keep ui-ux-pro-max and impeccable as the general UI/UX baseline.",
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
  "",
  "Response quality:",
  "- Answer the user's direct question first, then give concise evidence.",
  "- Do not claim perfection, completion, release, push, browser verification, or active runtime status without current evidence.",
  "- Keep final responses short and factual, with changed scope and validation when files were modified.",
  "",
  "Task scope discipline:",
  "- Work only on the requested task, its direct blockers, and regressions introduced by the current change.",
  "- Do not chase unrelated errors, warnings, tests, UI issues, backend endpoints, refactors, dependency warnings, or generated files.",
  "- If an unrelated pre-existing error appears, record it as unrelated, use narrower relevant validation when possible, and continue the requested work.",
  "- Broaden scope only when the user asks, when the unrelated issue directly prevents the requested task from being verified, or when the current change caused it.",
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
  "- Repetition does not convert an internal bug into an external blocker. Mark a goal BLOCKED only for an external or user-only condition after no meaningful local work remains; never wait for the user merely to resume incomplete code.",
  "- Never pause an incomplete code path waiting for the user to resume it.",
  "- When a goal is ACTIVE, never emit a final answer saying the work is incomplete or no complete result exists. Use commentary and continue execution. Before finalizing a goal task, read current goal status; final is allowed only for COMPLETE, valid external BLOCKED, or an explicit user request for status-only reporting.",
  "",
  "Local command autonomy:",
  "- Run and reuse normal project commands and local development services without asking the user. A Codex command prompt is a platform confirmation, not an agent question or task blocker.",
  "- Reuse a healthy existing service before starting another long-running process.",
  "",
  "Browser hard stop:",
  "- Never use a connector-created Chrome window for a task that depends on the user's visible browser.",
  "- Block a newly created automation/Codex window, temporary profile, or unverified profile. A control banner on the verified existing user tab is not an automatic block.",
  "- For Chrome, read the installed Chrome control skill and bootstrap its browser client only through mcp__node_repl__js, then use the extension binding, enumerate user.openTabs(), and claimTab() the verified user-owned tab.",
  "- Never use directly exposed mcp__playwright__*, mcp__chrome_devtools__*, or in-app-browser tools for Chrome work. Playwright is allowed only through the claimed tab's tab.playwright API. Use visible Windows control only if the plugin is unavailable. Never open another browser surface as recovery.",
  "- A transient Node REPL, browser-client, or extension bridge failure requires bootstrap-troubleshooting and chrome-troubleshooting plus retry on the same extension binding. Do not invent alternate import syntax or switch browser surfaces.",
  "- A task-local Node REPL or browser-client failure is THREAD_CONTROL_CHANNEL_DEGRADED, not proof that Chrome is unavailable. It cannot justify BLOCKED or asking the user to restart Chrome. Accept a trusted current VERIFIED_HANDOFF for the same user tab; request a fresh handoff after relevant code changes.",
  "- After the first local bridge failure, request the handoff and continue implementation. Do not expose retry counts, internal bridge errors, or a stopped-verification message; report only: Browser verification is being completed on your existing tab; implementation continues.",
  "- Before a browser-task turn ends, finalize claimed tabs through chrome.tabs.finalize(...) as the final browser action. This releases the user's tab for the next task without closing it and prevents stale ownership locks.",
  "- If claimTab() reports a stale browser-session owner, run scripts/repair-chrome-tab-ownership.ps1, reset the task browser binding, and reclaim the exact existing tab once. This is autonomous; do not ask another task or the user to intervene.",
  "- When browser or visual verification is required, keep the task active until the exact user-owned tab is claimed and verified. Build, tests, component reuse, source inspection, and structural equivalence cannot substitute for this gate or justify COMPLETE.",
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
  "- Every non-trivial T1-T4 code-changing task must spawn at least one bounded child when agent tooling is callable. Before the first project command or edit, show Agent route: <tier> | Agent: spawned <id or nickname>. The only valid no-spawn reason for code-changing work is TOOL_UNAVAILABLE.",
  "- Never claim UEEF routing or gates passed when required route evidence or child-agent evidence is missing.",
  "",
  "Design engineering skill routing:",
  "- Keep ui-ux-pro-max and impeccable as the general UI/UX baseline.",
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
  "",
  "Response quality:",
  "- Answer the user's direct question first, then give concise evidence.",
  "- Do not claim perfection, completion, release, push, browser verification, or active runtime status without current evidence.",
  "- Keep final responses short and factual, with changed scope and validation when files were modified.",
  "",
  "Task scope discipline:",
  "- Work only on the requested task, its direct blockers, and regressions introduced by the current change.",
  "- Do not chase unrelated errors, warnings, tests, UI issues, backend endpoints, refactors, dependency warnings, or generated files.",
  "- If an unrelated pre-existing error appears, record it as unrelated, use narrower relevant validation when possible, and continue the requested work.",
  "- Broaden scope only when the user asks, when the unrelated issue directly prevents the requested task from being verified, or when the current change caused it.",
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
  "- Repetition does not convert an internal bug into an external blocker. Mark a goal BLOCKED only for an external or user-only condition after no meaningful local work remains; never wait for the user merely to resume incomplete code.",
  "- Never pause an incomplete code path waiting for the user to resume it.",
  "- When a goal is ACTIVE, never emit a final answer saying the work is incomplete or no complete result exists. Use commentary and continue execution. Before finalizing a goal task, read current goal status; final is allowed only for COMPLETE, valid external BLOCKED, or an explicit user request for status-only reporting.",
  "",
  "Local command autonomy:",
  "- Run and reuse normal project commands and local development services without asking the user. A Codex command prompt is a platform confirmation, not an agent question or task blocker.",
  "- Reuse a healthy existing service before starting another long-running process.",
  "",
  "Browser hard stop:",
  "- Browser tasks must use the user's existing user-owned Chrome window and tab, not a connector-created Chrome window. Foreground or restored state is not required.",
  "- Newly created automation/Codex windows, temporary profiles, and unverified profiles are BLOCKED. A banner on a proven existing extension-claimed tab is not automatically blocked.",
  "- For Chrome, read the installed Chrome control skill and bootstrap its browser client only through mcp__node_repl__js, then use the extension binding, enumerate user.openTabs(), and claimTab() the verified user-owned tab. Extension attachment to an existing tab is allowed and must not be treated as a connector-created window.",
  "- Never use directly exposed mcp__playwright__*, mcp__chrome_devtools__*, or in-app-browser tools for Chrome work. Playwright is allowed only through the claimed tab's tab.playwright API.",
  "- A transient Node REPL, browser-client, or extension bridge failure requires bootstrap-troubleshooting and chrome-troubleshooting plus retry on the same extension binding. Do not invent alternate import syntax or switch browser surfaces.",
  "- A task-local Node REPL or browser-client failure is THREAD_CONTROL_CHANNEL_DEGRADED, not proof that Chrome is unavailable. It cannot justify BLOCKED or asking the user to restart Chrome. Accept a trusted current VERIFIED_HANDOFF for the same user tab; request a fresh handoff after relevant code changes.",
  "- After the first local bridge failure, request the handoff and continue implementation. Do not expose retry counts, internal bridge errors, or a stopped-verification message; report only: Browser verification is being completed on your existing tab; implementation continues.",
  "- Before a browser-task turn ends, finalize claimed tabs through chrome.tabs.finalize(...) as the final browser action. This releases the user's tab for the next task without closing it and prevents stale ownership locks.",
  "- If claimTab() reports a stale browser-session owner, run scripts/repair-chrome-tab-ownership.ps1, reset the task browser binding, and reclaim the exact existing tab once. This is autonomous; do not ask another task or the user to intervene.",
  "- When browser or visual verification is required, keep the task active until the exact user-owned tab is claimed and verified. Build, tests, component reuse, source inspection, and structural equivalence cannot substitute for this gate or justify COMPLETE.",
  "- Preserve the user's browser window state. Do not resize, emulate, move, restore, minimize, maximize, or alter full screen unless explicitly requested.",
  "- A minimized, background, or non-foreground user-owned Chrome window remains controllable through the extension and must not pause the goal. Continue non-visual work if a visual-only check is unavailable.",
  "- If the user-owned tab cannot be proven, stop without opening another browser. Use visible Windows control only when the Chrome plugin is unavailable and identity is verified.",
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
