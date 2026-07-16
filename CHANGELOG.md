# Changelog

## Release Notes Index

This file is a high-level changelog. Individual release notes are available in [docs/releases](docs/releases/) for every release from `v1.1.0` through `v2.8.18`; the `v1.0.0` baseline is recorded below but has no separate release-note file. Some intermediate releases are intentionally summarized here, so use the release-notes archive for their complete detail.

## 2.8.18 - 2026-07-16

- Added pack 59 Skill Invocation Protocol for mandatory skill discovery, routing, red flags, spec-plan execution, TDD evidence loops, bounded subagent review, and skill-authoring quality.
- Added a skill invocation protocol quality gate and checklist.
- Added Superpowers attribution with reviewed repository, commit, and MIT license context.
- Integrated skill protocol routing into core behavior, master loader, runtime sequence, quality gate selection, validation, generated Codex loader, and generated AGENTS.

## 2.8.17 - 2026-07-15

- Added an official UEEF skill/display icon asset at `assets/ueef-skill-icon.svg`.
- Added `assets/ueef-display.json` as the display metadata contract for UEEF skill surfaces.
- Added Windows and Unix `project-context-map` helpers for bounded broad-project discovery.
- Required large-project work to run a context map or equivalent repository map before broad implementation.
- Made `ueef-status.ps1` report runtime drift so stale runtimes cannot produce unqualified `ACTIVE`.
- Routed motion, animation, transition, and easing tasks through UIUX plus `emil-design-eng`.
- Added validation coverage for the new asset, scripts, release note, runtime sync text, and script execution.

## 2.8.16 - 2026-07-15

- Added shared-first reuse rules for behavior, UI, validation, data access, formatting, configuration, and design logic used in multiple places.
- Required design-system-first implementation: inspect shared components, tokens, layouts, registries, services, and pattern libraries before custom UI.
- Required import-based consumption from shared/common/library owners instead of feature-local copies.
- Added large-project discovery rules for module boundaries, aliases, barrel exports, registries, package boundaries, public APIs, and test utilities.
- Strengthened code-quality validation so reusable work must be placed in shared owners or documented as genuinely single-use.

## 2.8.15 - 2026-07-15

- Strengthened mandatory paired `ui-ux-pro-max` and `impeccable` evidence for UI/UX work.
- Added explicit file/folder ownership, no standalone-file-system, and file-size responsibility rules.
- Added backend performance coverage for server-side pagination, filtering, sorting, aggregation, projection, caching, cancellation, concurrency, serialization, authorization, and burst behavior.
- Added SSR/SSG/streaming/pre-rendering evaluation for routes where server rendering is useful.
- Added response-quality rules that prevent overclaiming without current evidence.
- Added end-to-end over-render prevention rules for frontend state/rendering and backend refresh/data delivery.
- Added animation performance rules for smooth, interruptible, compositor-friendly motion without layout thrash or unnecessary renders.
- Added task-scope discipline so agents do not chase unrelated errors or modify unrelated systems unless they block the requested work or were caused by the current change.

## 2.8.14 - 2026-07-14

- Fixed `UEEF_GLOBAL_PATH` normalization in Windows and Unix bootstrap scripts.
- Prevented valid runtime paths from producing false mandatory-file `BLOCKED` status.

## 2.8.13 - 2026-07-14

- Made runtime synchronization non-destructive for active runtimes.
- Added regression coverage that proves active-task files survive a framework update.

## 2.8.12 - 2026-07-14

- Added autonomous recovery for exact Chrome tab-ownership conflicts.
- Tasks now reset only the Codex extension host, rebootstrap the same Chrome connection, and reclaim the user tab without cross-thread messages or user action.

## 2.8.11 - 2026-07-14

- Required `chrome.tabs.finalize(...)` as the final browser action for every browser-task turn.
- Prevented stale user-tab ownership locks from carrying into later tasks while preserving the user's open Chrome tab.

## 2.8.10 - 2026-07-13

- Added executable lifecycle validation for the only allowed interim browser-recovery status.
- Rejected retry-count and stopped-verification wording whenever a task-local control channel is degraded.

## 2.8.9 - 2026-07-13

- Added a mandatory first-failure handoff protocol for task-local Chrome control degradation.
- Prohibited exposing retry counts, internal bridge failures, or stopped-verification messages to users.
- Added contract validation for the required recovery status in both global runtime templates.

## 2.8.8 - 2026-07-13

- Added trusted same-tab browser evidence handoff when one task's Node REPL channel is degraded.
- Prohibited treating a task-local bridge failure as Chrome unavailability, blocking work, or grounds to ask the user to restart Chrome.
- Added lifecycle enforcement for current-state handoff evidence and independent Chrome-unavailability claims.

## 2.8.7 - 2026-07-13

- Added mandatory recovery for transient Node REPL, browser-client, and Chrome extension bridge failures.
- Prohibited completion when required same-tab visual verification is missing.
- Rejected build, tests, component reuse, source inspection, and structural equivalence as substitutes for browser evidence.

## 2.8.6 - 2026-07-13

- Forced Chrome work through the installed Chrome plugin, Node REPL browser client, extension binding, and exact-object tab claim.
- Rejected directly exposed Playwright, Chrome DevTools, in-app-browser, and isolated-context substitutes for Chrome tasks.
- Removed contradictory fallback and window-restoration rules and added cross-platform contract coverage.

## 2.8.5 - 2026-07-12

- Prohibited final answers that only report incompleteness while a goal remains active.
- Required current goal-status verification before goal-task finalization.
- Added a canonical finalization predicate and generated-runtime enforcement.

## 2.8.4 - 2026-07-12

- Prohibited goal blocking for internal implementation, test, API, facade, schema, and save-contract failures.
- Replaced Engineering Guardian task-stopping language across the pack with completion/release blocking while fixes continue.
- Separated runtime, delivery, and goal status semantics and added generated-runtime regression coverage.

## 2.8.3 - 2026-07-12

- Allowed extension control of minimized, background, and non-foreground user-owned Chrome windows.
- Prevented a visual-only limitation from pausing or blocking the whole engineering goal.
- Removed stale generated-loader rules that blanket-blocked control banners.

## 2.8.2 - 2026-07-12

- Aligned browser control with Chrome extension `openTabs()` and exact-object `claimTab()`.
- Removed the conflicting Windows-first policy and banner-only blocking rule.
- Fixed default environment bootstrap collection mutation and added executable contract coverage.

## 2.8.1 - 2026-07-12

- Forced non-trivial code changes to emit a child-agent route when tooling is callable.
- Required visible pre-edit route evidence and rejected silent UEEF pass claims.
- Reserved `TOOL_UNAVAILABLE` as the only no-spawn reason for code-changing work.

## 2.8.0 - 2026-07-12

- Activated agent routing as a runtime-verified contract across Codex tasks.
- Capped every model and child-agent reasoning override at medium.
- Added cross-platform route schema, state proof, and status enforcement.

## 2.7.1 - 2026-07-12

- Hardened task routing against unclassified critical risk, unavailable agents/models, and unjustified parallel fan-out.
- Secured runtime target containment and made active-state evidence agent-aware and validated.
- Expanded drift checking from a small critical list to the complete source runtime.
- Repaired quality-gate selection, Unix audit/status/bootstrap parity, installers, updates, cleanup safety, and release documentation.

## 2.7.0 - 2026-07-12

- Added reproducible installation for the Emil Kowalski design-engineering skill suite.
- Added task-specific routing for design engineering, animation review, animation audits, motion vocabulary, and Apple-style interactions.
- Added Environment Bootstrap detection without making specialized motion skills universal blockers.
- Added runtime and validator coverage for the complete design skill suite.

## 2.6.0 - 2026-07-11

- Added mandatory task complexity and risk routing for every task.
- Added capability-based model selection and bounded multi-agent topologies.
- Added token-economy, escalation, fallback, and independent verification controls.
- Added a deterministic PowerShell route selector and validation coverage.
- Added Unix selector parity, expanded critical risk floors, and behavioral tests.
- Corrected agent spawning so complexity alone never bypasses the delegation-benefit test.
- Fixed generated runtime loader parity so continuation and local-command policies survive installation and sync.

## 1.5.0 - 2026-07-10

- Added pack 51 Browser Session Control.
- Browser tasks now require the user's actually opened browser, target tab, visible domain, and signed-in state.
- New browser/context/profile sessions are prohibited by default and require explicit user approval.
- Added privacy rules forbidding inspection of cookies, passwords, tokens, local storage, and profile stores.
- Added browser session runtime preflight, release-blocking gate, checklist, loader selection, and validation coverage.

## 1.4.7 - 2026-07-10

- Unix bootstrap now defaults to `$HOME/.codex` when `CODEX_HOME` is not set.
- Unix bootstrap auto-detects Frontend, UIUX, Backend, Database, and DevOps profiles from repository signals.
- Explicit `UEEF_PROFILES` still overrides automatic detection.

## 1.4.6 - 2026-07-10

- Added automatic Environment Bootstrap profile detection when no profiles are passed.
- Detection covers frontend manifests and source extensions, backend SDK/project files, database/migration signals, UI assets, and Docker/CI files.
- Manual profile selection remains available for task scope not visible in repository files.
- Fixed validator matching to use literal behavior terms safely.

## 1.4.5 - 2026-07-10

- Completed Unix validator coverage for v1.4.4 release notes and added version/manifest parity checking.
- Confirmed shell execution is unavailable in the current Windows host because WSL has no installed distribution; no OS subsystem was installed.

## 1.4.4 - 2026-07-10

- Aligned `environment-bootstrap.sh` with PowerShell profile selection and readiness semantics.
- Unix bootstrap now checks Core, AI, selected UIUX, both `ui-ux-pro-max` and `impeccable`, and profile output consistently.
- Unix validation now requires all pack 50 modules and recent release notes.

## 1.4.3 - 2026-07-10

- Added `UEEF-LOADER.md` to the source repository as the portable loader contract used to generate active Codex runtime loaders.
- Updated PowerShell and Unix validation to require the source loader template.

## 1.4.2 - 2026-07-10

- Strengthened validation to require every Environment Bootstrap module and key dependency-policy behavior.
- Strengthened UIUX profile evidence so `ui-ux-pro-max` and `impeccable` must both be listed and pass together.
- Added robustness for missing `CODEX_HOME`: bootstrap now reports a clean BLOCKED result instead of throwing a null-path error.

## 1.4.1 - 2026-07-10

- Completed and committed all pack 50 environment bootstrap profile modules.
- Fixed UIUX profile enforcement so `ui-ux-pro-max` and `impeccable` are both Mandatory and selected together for UI/UX work.
- Verified Core, AI, and UIUX bootstrap readiness with 11 Mandatory checks passing.

## 1.4.0 - 2026-07-10

- Added pack 50 Smart Environment Bootstrap with Core, Frontend, Backend, Database, UIUX, DevOps, AI, and Optional profiles.
- Added dependency levels and blocking policy: Mandatory blocks, Recommended warns, Optional continues.
- Added PowerShell and Unix bootstrap checkers with runtime, skills, tools, and profile evidence.
- Integrated bootstrap before inspection and planning through Core, Master Loader, Runtime Sequence, quality gate, scorecard, checklist, validation, and release metadata.

## 1.3.0 - 2026-07-10

- Added pack 49 Engineering Guardian with zero-regression policy and 26 protection modules.
- Added regression monitors for production, UI, performance, security, architecture, design, dependencies, database, API contracts, debt, complexity, code, and folders.
- Added automatic improvement policy, self-criticism engine, final guardian gate, health score, maintenance review, future-proof review, product review, and final checklist.
- Integrated Guardian selection into Core, Master Loader, Runtime Sequence, AI review, quality gates, scorecards, checklists, validation, and release metadata.

## 1.2.0 - 2026-07-10

- Added pack 48 design governance with 31 files covering design language, tokens, visual systems, components, patterns, layouts, themes, interactions, overlays, drift, and reuse.
- Added mandatory search-before-create and no-reinvention rules.
- Added governance gate, scorecard, checklist, and review template.
- Integrated design governance into core behavior, runtime preflight, Master Loader, Master Index, UI, UX, accessibility, frontend, React, Angular, design-system, quality, scorecard, checklist, and template packs.

## 1.1.0 - 2026-07-10

- Added application-model, identity, authorization, entitlement, and tenant-isolation pack 45.
- Added unified design-system consistency and reuse pack 46.
- Added the 52-file theme, responsive, interaction, security, and performance pack 47.
- Added light, dark, and system themes, semantic tokens, responsive contracts, deterministic overlays, security verification, and performance budgets.
- Added decision graphs, a release-blocking gate, scorecard, checklists, templates, smoke tests, and expanded validation.
- Updated core selection, runtime preflight, runtime synchronization, installation guidance, and release metadata.

## 1.0.0 - 2026-07-09

- Created UEEF Enterprise Edition baseline.
- Added sequential framework packs from foundation through future expansion.
- Added safe installers, update scripts, validation scripts, examples, docs, templates, checklists, decision graphs, quality gates, and scorecards.
