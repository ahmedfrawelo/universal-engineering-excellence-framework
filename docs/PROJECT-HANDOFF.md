# UEEF Project Handoff

> **Current handoff:** [`docs/handoffs/2026-08-06-ueef-delivery.md`](handoffs/2026-08-06-ueef-delivery.md) for UEEF `2.25.10` and the current delivery change set.
>
> Everything below is the preserved 2026-08-02 legacy snapshot. Use it only for historical context; current command output and the current handoff above are authoritative.

**Purpose:** تسليم المشروع لوكيل أو مطور جديد يستطيع فهمه وتشغيله والتحقق منه بدون الاعتماد على ذاكرة الجلسة السابقة.

**Snapshot date:** 2026-08-02
**Repository:** `E:\MY DATA\div\universal-engineering-excellence-framework`
**Upstream:** `https://github.com/ahmedfrawelo/universal-engineering-excellence-framework`
**Version:** `2.25.0`
**Authoritative commit:** resolve `v2.25.0` or run `git rev-parse HEAD`; do not rely on a copied hash in this handoff.

## 1. What this project is

UEEF is an installable engineering operating system for AI coding assistants. It is not an application product and does not contain the user's business frontend/backend. It supplies:

- task routing and proportional model/agent selection;
- inspect-before-edit and shared-owner architecture rules;
- security, performance, accessibility, UI/UX, testing, documentation, and production gates;
- evidence artifacts and provenance checks;
- Codex, Cursor, and generic AGENTS-compatible adapters;
- transactional installers, runtime synchronization, backups, drift checks, and rollback;
- browser-control safety rules for the user's existing Chrome tab;
- optional skill/plugin/MCP capability governance.

The source checkout is the product source. The installed Codex runtime is a generated, self-contained copy and must be synchronized after source changes.

## 2. Current verified state

The managed runtime currently reports:

- `Installed: YES`
- `Active state: PASS`
- `Runtime drift: PASS`
- `Runtime source revision: PASS`
- `Overall: ACTIVE`
- UEEF version `2.25.0`

Run the authoritative check from the source repository:

```powershell
& .\scripts\ueef-status.ps1
```

The currently synchronized runtime is:

```text
D:\shared folder\codex-home\ueef\codex
D:\shared folder\codex-home\AGENTS.md
```

Backups are kept outside `CODEX_HOME` under the configured external backup root. Do not delete or edit the generated runtime by hand unless performing a documented recovery.

## 3. Core execution flow

Every non-trivial task follows this sequence:

1. Read the global loader and run the runtime check.
2. Keep `Loaded` exactly `boot-loader, core-system`.
3. Route the task through pack 58 and classify T0–T4.
4. Select only the modules, skills, tools, and gates triggered by the task.
5. Inspect the target project, ownership boundaries, conventions, and current behavior.
6. Translate the request into observable acceptance criteria and exclusions.
7. Plan before multi-file edits; keep one dependent step in progress.
8. Implement in the existing owner, preserving dirty-worktree scope.
9. Run proportional tests and quality gates.
10. For T2+, create and validate evidence using `new-task-evidence.ps1` and `validate-task-evidence.ps1`.
11. Create a completion audit mapping every explicit requirement to passing acceptance evidence.
12. Only then may the goal become `COMPLETE` or report 100 percent.
13. For each material milestone in a multi-step active goal, report what the agent currently understands, the named current step and its percentage, the separate conservative overall percentage, new evidence, current action, and next gate.
14. When implementation ends, report `implementation complete` and immediately enter literal goal review with the goal still `ACTIVE`.
15. The Completion Audit checklist must mark every requirement against requested implementation, best feasible in-scope outcome, and current evidence. Inspect all changed surfaces and fix task-caused regressions only; record unrelated findings without expanding scope.
16. After the full review passes, report that the goal is complete and stop. Do not ask whether anything is missing or whether more work is wanted.
17. Exception before completion: if the user already said they have another item before finish, keep the goal active and ask for it. The goal cannot complete until that commitment is clarified and resolved; this is not an optional post-completion question.
18. Route every new goal update against the active plan. Merge current-step changes; save and restore a resume point for prior-step corrections; queue future changes with order, dependencies, and acceptance criteria; pause/replan only when continuing is invalid; preserve state and ask when requirements conflict.
19. Completion review must compare every literal requirement with an inventory of actual implementation and observed behavior plus current evidence. Reverse-trace every implementation item to a requirement; prose review or unchecked/untraced implementation cannot pass.

The completion audit is now an executable gate. Validate it with:

```powershell
& .\scripts\validate-completion-audit.ps1 -Path .\.ueef\completion-audit\<task>.json
```

`remainingWork` and `knownProblems` must be empty. A green build, passing generic tests, code presence, or an optimistic summary is not sufficient.

## 4. Repository map

| Path | Ownership and purpose |
|---|---|
| `framework/_domains` | Physical fast-navigation layer. Start here to pick the right domain before opening numbered packs. |
| `framework/DOMAIN_MAP.md` | Compatibility entrypoint that points to the `_domains` organization folder. |
| `framework/MASTER_INDEX.md` | Generated exact inventory of every framework Markdown module by stable numbered pack. |
| `framework/00-*`-`61-*` | Stable numbered pack paths. Keep these paths stable unless the loader, validators, release manifest, and runtime sync are updated together. |
| `framework/00-foundation`–`21-framework-resources/07-future` | Foundational engineering, architecture, code quality, security, performance, frontend/backend, AI, scorecards, checklists, templates, examples, scripts, and references. |
| `framework/17-product-platform/01-identity-access-application-models` | Identity, permissions, tenancy, and access-aware application rules. |
| `framework/16-design-system/01-consistency-reuse` | Design-system ownership, token reuse, and shared component consistency. |
| `framework/16-design-system/02-theme-responsive-interaction-security-performance` | Theme, responsive, interaction, security, and performance UI gates. |
| `framework/16-design-system/03-governance` | Search-first design governance and reuse decisions. |
| `framework/12-delivery-quality/08-engineering-guardian` | Prevents regressions from becoming false completion or release claims. |
| `framework/18-runtime-operations/01-environment-bootstrap` | Environment, capability, runtime, and workspace readiness. |
| `framework/18-runtime-operations/02-browser-session-control` | Existing-Chrome control, tab ownership, recovery, and visual evidence. |
| `framework/18-runtime-operations/03-workspace-hygiene` | File boundaries, cleanup, artifacts, and workspace safety. |
| `framework/17-product-platform/02-skeleton-loading` | Shared loading/skeleton behavior. |
| `framework/16-design-system/04-intelligence` | UI design intelligence and searchable references. |
| `framework/18-runtime-operations/04-continuous-assurance` | Repeated assurance and failure propagation. |
| `framework/17-product-platform/03-data-grid-platform` | Data-grid contract, scale, accessibility, and live refresh. |
| `framework/17-product-platform/04-application-shell-design` | App-shell structure and responsive shell behavior. |
| `framework/19-agent-workflow/01-model-orchestration` | Tier, capability, model, delegation, and escalation routing. |
| `framework/19-agent-workflow/02-skill-invocation-protocol` | Skill trigger, selection, and verification discipline. |
| `framework/19-agent-workflow/03-spec-driven-development` | Requirements, acceptance criteria, traceability, and convergence. |
| `framework/20-repository-evolution/01-project-modernization` | Baselines, migration slices, compatibility, rollback, and freshness. |
| `framework/20-repository-evolution/02-performance-forensics` | Evidence-first performance investigations. |
| `scripts` | Installers, sync/update, preflight, reports, validators, tests, adapters, and recovery utilities. |
| `config` | Release metadata, enforcement registry, adapters, preferred skills/capabilities, and browser emergency policy. |
| `docs` | Installation, verification, architecture decisions, release notes, governance, and this handoff. |
| `examples` | Tested Codex/Cursor/generic guidance and unverified Claude guidance. |
| `.ueef` | Ignored task-local specs, evidence, completion audits, and generated working artifacts. |

## 5. Entrypoints and canonical files

- `UEEF-LOADER.md`: source global loader template.
- `framework/01-core/00-boot-loader.md`: boot rules.
- `framework/01-core/00-core-system.md`: always-loaded core contract.
- `framework/01-core/01-master-loader.md`: module selector; it is not itself a loaded module.
- `framework/03-runtime/00-runtime-sequence.md`: runtime sequence and evidence fields.
- `framework/12-delivery-quality/04-quality-gates/final-gate.md`: final completion/release gate.
- `config/enforcement-registry.json`: T2+ domain/gate mapping and required fields.
- `release-manifest.json`: version, tracked Markdown count, pack count, entrypoints, and release notes.
- `docs/releases/v2.25.0.md`: current release notes.

## 6. Important current behavior

### Completion truthfulness

Release `2.25.0` includes:

- `framework/21-framework-resources/01-templates/completion-audit-template.json`;
- `scripts/validate-completion-audit.ps1`;
- `scripts/validate-completion-audit.mjs` and its Unix wrapper;
- `scripts/test-completion-audit.ps1`;
- lifecycle integration in `scripts/validate-goal-lifecycle.ps1` and its Unix counterpart.

The lifecycle validator rejects `COMPLETE` unless a valid completion-audit path is supplied and passes. It also preserves status-only responses and valid external-blocker rules.

Completion audits use schema version 2. Before `COMPLETE`, `sourceReview` must preserve the original goal text and its SHA-256, then cover every non-whitespace character with contiguous exact review units. Each unit is classified and linked to at least one passing requirement; gaps, overlaps, altered quotes, hash mismatches, or unlinked units are rejected.

### Browser control

Browser work is explicit-task only and uses the user's existing Chrome window/profile/session. The default is a dedicated task tab created through the explicit Chrome-family binding; the user's working tab is not claimed or navigated unless requested. Never use a default selector that can choose the in-app browser, or create another window/browser/profile/session/context/panel. Every recovery status must name the failed stage, observed reason, and next action.

Loopback Chrome DevTools/CDP is an emergency last resort only after every configured same-target stage has recorded stage/reason evidence, explicit user authorization, and:

```powershell
& .\scripts\get-remote-debugging-readiness.ps1 -AuthorizedLastResort -PriorStageFailure <recorded-stages> -ExpectedTargetId <dedicated-target-id>
```

must return `READY_LAST_RESORT` with `sameTargetProven: true`. Both the browser and exact page-target sockets must be loopback WebSockets. It must not inspect cookies, passwords, storage, history, or profile data. Stricter host or installed-skill rules win.

### Local service reuse

Before starting a development service, `scripts/get-local-service-readiness.ps1` checks the expected port, health response, and project ownership. Reuse is allowed only when both health and ownership are proven. An unhealthy or unverified listener must be diagnosed; it never authorizes a duplicate process or alternate port.

### Model capacity

`Selected model is at capacity` is a provider/account capacity condition, not a UEEF repository failure. UEEF can preserve the task, classify the condition, and use an available model according to the host's routing capabilities. It must not rotate ChatGPT accounts or cookies automatically. Account changes remain manual; API-key routing is a separate, explicitly authorized integration.

## 7. Installation and synchronization

Windows Codex installation:

```powershell
& .\scripts\install-codex.ps1
```

Preferred capabilities (missing-only):

```powershell
& .\scripts\reconcile-preferred-capabilities.ps1 -Install
```

Synchronize source into the active runtime after a source change:

```powershell
& .\scripts\sync-runtime.ps1 -CodexHome 'D:\shared folder\codex-home' -Agent codex -BackupRoot 'D:\shared folder\codex-home-backups'
& 'D:\shared folder\codex-home\ueef\codex\scripts\ueef-status.ps1'
```

Require `Overall: ACTIVE`, `Runtime drift: PASS`, and `Runtime source revision: PASS`. Never claim the source checkout alone is the active runtime.

## 8. Validation cookbook

Fast source validation:

```powershell
& .\scripts\validate-framework.ps1
```

Focused lifecycle/completion checks:

```powershell
& .\scripts\test-completion-audit.ps1
& .\scripts\test-goal-lifecycle.ps1
& .\scripts\test-delivery-continuation-contract.ps1
& .\scripts\test-runtime-hardening.ps1
```

Architecture and file ownership reports:

```powershell
& .\scripts\get-architecture-report.ps1 -RepositoryPath . -Json
& .\scripts\get-file-organization-report.ps1 -RepositoryPath . -Json
```

T2+ evidence:

```powershell
& .\scripts\new-task-evidence.ps1 -TaskId <id> -Tier T2 -SelectedDomain <domains> -OutputPath .\.ueef\evidence\<id>.json
& .\scripts\validate-task-evidence.ps1 -Tier T2 -SelectedDomain <domains> -EvidencePath .\.ueef\evidence\<id>.json
```

Task preflight:

```powershell
& .\scripts\get-ueef-task-preflight.ps1 -Task '<task description>' -Json
```

For browser tasks add `-TaskTag browser`; do not call a browser tool before the `browserGate` is resolved.

## 9. Capabilities, skills, plugins, and MCP

Sources of truth:

- `config/preferred-skills.json`: optional user-installed skills, triggers, pinned repositories, and install evidence.
- `config/preferred-capabilities.json`: preferred Codex plugins and MCPs; these do not share the user-skill installation lifecycle.
- `scripts/get-capability-health.ps1`: static health view.
- `scripts/reconcile-preferred-capabilities.ps1`: missing-only reconciliation; reports platform-managed actions instead of downloading bundled/remote plugins incorrectly.

Skills are trigger-selected, not all loaded into every task. The always-loaded line must remain exactly `Loaded: boot-loader, core-system.`

## 10. Git and release rules

Inspect before staging. Preserve unrelated worktree changes. Before commit:

```powershell
git diff --check
git diff --cached --check
git status --short
```

Release publishing is separate from local sync. The release publisher requires a clean, validated source tree and CI success on the exact commit. Do not push or publish unless explicitly requested.

Current release metadata is in `release-manifest.json`; update version, tracked counts, changelog, and release notes together when making a release.

## 11. Known limitations and non-goals

- UEEF cannot fix provider model capacity or force a selected model to become available.
- UEEF cannot safely auto-rotate ChatGPT browser accounts without an official account-switching interface.
- Source validation does not prove a user-facing browser behavior; required browser/visual evidence remains mandatory for those tasks.
- Unix capability health is intentionally reported as `UNSUPPORTED_ON_UNIX` where Windows parity is not proven.
- `examples/claude-code/` is guidance only and not a tested adapter claim.
- `.ueef` artifacts are task-local and ignored; copy or export them when durable handoff evidence is required.

## 12. First-day checklist for the next agent

1. Run `scripts/ueef-status.ps1` and confirm `Overall: ACTIVE`.
2. Read this handoff, then read only the relevant Master Loader modules.
3. Run `git status --short`; do not reset or clean unknown changes.
4. Run `scripts/project-context-map.ps1 -Path . -MaxItems 40` for broad work.
5. Run task preflight and record route rationale.
6. Define explicit requirements and acceptance criteria before editing.
7. Preserve the existing owner and shared patterns.
8. Test the exact reported behavior, not only compilation.
9. Build and validate T2+ evidence plus a completion audit.
10. Synchronize the runtime and verify drift before claiming activation.

## 13. Handoff acceptance

This document is a navigation aid, not a replacement for current command output. The next agent must re-run status, inspect the worktree, and validate the relevant behavior before making current claims.
