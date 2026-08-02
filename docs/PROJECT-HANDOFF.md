# UEEF Project Handoff

**Purpose:** تسليم المشروع لوكيل أو مطور جديد يستطيع فهمه وتشغيله والتحقق منه بدون الاعتماد على ذاكرة الجلسة السابقة.

**Snapshot date:** 2026-08-02  
**Repository:** `E:\MY DATA\div\universal-engineering-excellence-framework`  
**Upstream:** `https://github.com/ahmedfrawelo/universal-engineering-excellence-framework`  
**Version:** `2.23.0`  
**Latest local commit:** `11d1ff1 fix: require evidence-backed task completion`

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
- UEEF version `2.23.0`

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

The completion audit is now an executable gate. Validate it with:

```powershell
& .\scripts\validate-completion-audit.ps1 -Path .\.ueef\completion-audit\<task>.json
```

`remainingWork` and `knownProblems` must be empty. A green build, passing generic tests, code presence, or an optimistic summary is not sufficient.

## 4. Repository map

| Path | Ownership and purpose |
|---|---|
| `framework/00-foundation`–`44-future` | Foundational engineering, architecture, code quality, security, performance, frontend/backend, AI, scorecards, checklists, templates, examples, scripts, and references. |
| `framework/45-identity-access-application-models` | Identity, permissions, tenancy, and access-aware application rules. |
| `framework/46-design-system-consistency-reuse` | Design-system ownership, token reuse, and shared component consistency. |
| `framework/47-theme-responsive-interaction-security-performance` | Theme, responsive, interaction, security, and performance UI gates. |
| `framework/48-design-governance` | Search-first design governance and reuse decisions. |
| `framework/49-engineering-guardian` | Prevents regressions from becoming false completion or release claims. |
| `framework/50-environment-bootstrap` | Environment, capability, runtime, and workspace readiness. |
| `framework/51-browser-session-control` | Existing-Chrome control, tab ownership, recovery, and visual evidence. |
| `framework/52-workspace-hygiene` | File boundaries, cleanup, artifacts, and workspace safety. |
| `framework/53-skeleton-loading` | Shared loading/skeleton behavior. |
| `framework/54-design-intelligence` | UI design intelligence and searchable references. |
| `framework/55-continuous-assurance` | Repeated assurance and failure propagation. |
| `framework/56-data-grid-platform` | Data-grid contract, scale, accessibility, and live refresh. |
| `framework/57-application-shell-design` | App-shell structure and responsive shell behavior. |
| `framework/58-agent-model-orchestration` | Tier, capability, model, delegation, and escalation routing. |
| `framework/59-skill-invocation-protocol` | Skill trigger, selection, and verification discipline. |
| `framework/60-spec-driven-development` | Requirements, acceptance criteria, traceability, and convergence. |
| `framework/61-project-modernization` | Baselines, migration slices, compatibility, rollback, and freshness. |
| `framework/62-performance-forensics` | Evidence-first performance investigations. |
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
- `framework/27-quality-gates/final-gate.md`: final completion/release gate.
- `config/enforcement-registry.json`: T2+ domain/gate mapping and required fields.
- `release-manifest.json`: version, tracked Markdown count, pack count, entrypoints, and release notes.
- `docs/releases/v2.23.0.md`: current release notes.

## 6. Important current behavior

### Completion truthfulness

The latest change (`11d1ff1`) adds:

- `framework/38-templates/completion-audit-template.json`;
- `scripts/validate-completion-audit.ps1`;
- `scripts/test-completion-audit.ps1`;
- lifecycle integration in `scripts/validate-goal-lifecycle.ps1` and its Unix counterpart.

The lifecycle validator rejects `COMPLETE` unless a valid completion-audit path is supplied and passes. It also preserves status-only responses and valid external-blocker rules.

### Browser control

Browser work is explicit-task only and uses the user's existing Chrome tab. Never launch Playwright, a second profile/context, IDE Simple Browser, in-app browser, or a connector-created Chrome window. The normal path uses the installed Chrome control plugin and exact `user.openTabs()`/`claimTab()` ownership flow.

Loopback Chrome DevTools/CDP is an emergency last resort only after every configured same-tab stage has recorded failure evidence, explicit user authorization, and:

```powershell
& .\scripts\get-remote-debugging-readiness.ps1 -AuthorizedLastResort -PriorStageFailure <recorded-stages>
```

must return `READY_LAST_RESORT`. It may attach only to an existing page target on loopback and must not inspect cookies, passwords, storage, history, or profile data. Stricter host or installed-skill rules win.

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
