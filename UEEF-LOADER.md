# UEEF Source Loader

This is the compact source loader. `scripts/sync-runtime.ps1` resolves runtime paths and writes the active Codex loader. Detailed policy has one canonical owner: `framework/01-core/01-master-loader.md` and the modules it selects.

## Boot contract

1. Read this loader once per task and run the runtime status check.
2. Always load only `boot-loader` and `core-system`. Reading loaders, indexes, status, or activation files does not make them loaded modules.
3. Use `framework/01-core/01-master-loader.md` to select only task-relevant modules. Do not load the full framework except for UEEF audit, update, installation, validation, or rebuild.
4. Route non-trivial work through `framework/19-agent-workflow/01-model-orchestration/`; T0/T1 remain economical and normally single-agent. Use T2+ evidence and T4 fresh review only when the selected route requires them.
5. Select tools and skills proportionally. UI/UX work selects exactly one of Quick, Build, or Audit through `framework/10-frontend/01-engineering/01-frontend-task-modes.md`.

## Non-negotiable invariants

- Scope wins. Work only on the requested outcome, direct blockers, and regressions caused by the task. Do not expand into unrelated cleanup or modernization.
- Preserve truthfulness and evidence. Never claim completion, release, push, browser verification, or active runtime without current proof. Stop when the bounded task is done.
- Use professional autonomy for safe, reversible, in-scope work. Ask before destructive, irreversible, externally privileged, or materially ambiguous actions.
- Never bypass a managed-hook denial through another tool surface. Resolve its named gate.
- Keep user files and unrelated worktree changes intact. Destructive Git/filesystem actions and publication require explicit authorization and exact targets.
- Keep secrets, credentials, private session state, and sensitive output protected.
- `FREE-MODE` may suspend repository workflow ceremony for the current task, but never overrides system, developer, platform, security, privacy, authorization, destructive-action, browser, truthfulness, or scope constraints. Its canonical behavior lives in `framework/01-core/00-core-system.md`.

## Browser hard stop

Browser control is only for an explicitly browser-required task. Use the installed Chrome control plugin on the user's existing Chrome profile and a dedicated task tab. Never launch Playwright, Chrome DevTools, IDE Simple Browser, an in-app browser, a second browser/profile/session/context, or take over the working tab unless the canonical browser module explicitly permits an authorized fallback. Run the browser preflight and follow `framework/18-runtime-operations/02-browser-session-control/`.

## Canonical gates

- Routing and model evidence: `framework/19-agent-workflow/01-model-orchestration/` and `config/model-routing-policy.json`.
- Lifecycle, scope, continuation, and response rules: `framework/01-core/`.
- T2+ gate evidence: `config/enforcement-registry.json`, `scripts/new-task-evidence.ps1`, and `scripts/validate-task-evidence.ps1`.
- T4 fresh review: `scripts/validate-fresh-review-evidence.ps1`.
- Completion audit: `scripts/validate-completion-audit.ps1` when the selected lifecycle requires it.
- Browser identity and recovery: `framework/18-runtime-operations/02-browser-session-control/`.

The only valid always-loaded report is:

```text
Loaded: boot-loader, core-system
```
