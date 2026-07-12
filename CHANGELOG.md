# Changelog

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
