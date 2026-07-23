# Quick Start

1. Clone the repository: git clone https://github.com/ahmedfrawelo/universal-engineering-excellence-framework.git.
2. Enter it: cd universal-engineering-excellence-framework.
3. Install for Codex: .\scripts\install-codex.ps1 on Windows or ./scripts/install-codex.sh on Unix.
4. Verify: run .\scripts\validate-framework.ps1.
5. First use: have Codex read the installed `UEEF-LOADER.md` before the task. It loads `boot-loader` and `core-system`, then uses the master loader to select task-specific modules.

UEEF is active when the assistant applies only the evidence and controls proportionate to the task, then verifies the requested outcome.

The current release is 2.17.1. See [VERSION.md](VERSION.md) for the version policy and [docs/releases](docs/releases/) for individual release notes. Codex sync installs Open Design skills only when you pass `-InstallOpenDesignSkills`.

## Minimal path

1. Install: `./scripts/install-codex.ps1`.
2. Check runtime: `./scripts/ueef-status.ps1`.
3. Preflight a non-trivial task: `./scripts/get-ueef-task-preflight.ps1 -Task 'Describe the task'`.
4. Make the scoped edit using the selected packs and gates.
5. Export evidence when needed: `./scripts/export-ueef-evidence.ps1 -RepositoryPath . -Preview`.

## AI must do only what you asked

- Your requested scope wins over continuation, delegation, audits, modernization, and optional improvements. The assistant expands work only when you ask or a direct blocker prevents verification.
- A bounded answer, review, or small change ends when complete; it does not become an automatic cleanup campaign.
- `T0/T1` work starts core-only. Bootstrap, broad gates, dependency inventory, and extra skills are used only when the task actually needs them.
- A child agent is optional for `T1`; it is used only for a genuinely independent benefit. The route should state the reason for spawning or not spawning.
- Browser control is used only when you explicitly ask for browser/site/visual work or an existing user session is directly required. It always uses your existing Chrome tab, never a second browser.
- If the AI starts expanding scope or responding below the requested depth, run `git pull` and then `./scripts/sync-runtime.ps1` so the installed runtime receives the `2.16` intent-first policy.
- To use the opt-in strict policy, resolve the `strict-scope` team profile: `./scripts/resolve-team-policy.ps1 -Profile strict-scope -Json`. It keeps `T0/T1` gates focused and forbids autonomous upgrades without an explicit request.
- If difficult work still feels artificially limited after `2.16+`, the installed master loader/runtime is likely old: run `git pull`, `./scripts/sync-runtime.ps1`, then `./scripts/ueef-status.ps1`.
- Intent-fidelity regressions run on both validation paths: `test-intent-fidelity-contract.ps1` on Windows and `test-intent-fidelity-contract.sh` on Unix.

Strict scope remains opt-in. Its machine-readable policy can be inspected without changing the active profile:

```json
{
  "profile": "strict-scope",
  "autonomousUpgrades": false,
  "t0t1": "focused"
}
```

## Runtime Check

Browser work = your existing Chrome only; never a second browser.

After any browser-policy release, synchronize the installed runtime before the next browser task: run `./scripts/sync-runtime.ps1` from the source repository (or reinstall with the Codex installer), then run `./scripts/ueef-status.ps1`. If the assistant still opens or proposes another browser, profile, context, IDE browser, or in-app browser, sync the runtime immediately; do not treat the source repository alone as proof that the installed loader was updated.

Before asking an AI assistant to modify a project, verify UEEF:

```powershell
.\scripts\ueef-status.ps1
```

The assistant must start non-trivial engineering work with the UEEF Runtime Check block and finish with the UEEF Verification block.

## Optional workflow tools

Use these only when the task needs them; routine work stays lightweight.

```powershell
# Create and validate a project-local specification workflow.
.\scripts\new-spec-workflow.ps1 -Id feature-name
.\scripts\validate-spec-workflow.ps1 -Path .\.ueef\specs\feature-name -Mode Draft

# Inspect configured skills, MCPs, plugins, and the combined UEEF health view.
.\scripts\get-capability-health.ps1
.\scripts\get-ueef-health.ps1

# Explain the selected capability and workflow profile for a task.
.\scripts\select-capability-profile.ps1 -Task 'Describe the task here'

# Compose task route, profile, and workflow evidence before non-trivial work.
.\scripts\get-ueef-task-preflight.ps1 -Task 'Describe the task here'

# Browser tasks add a mandatory hard-fail browser gate before any browser tool.
.\scripts\get-ueef-task-preflight.ps1 -Task 'Inspect the existing Chrome tab' -TaskTag browser -Json

# Inspect a multi-file change before selecting packs and gates. Results are heuristic.
.\scripts\get-diff-impact.ps1 -RepositoryPath . -Json

# Keep an explicit project-local decision or lesson (opt-in; rejects secrets).
.\scripts\write-project-memory.ps1 -Kind decision -Title 'Cache policy' -Detail 'Use explicit invalidation.' -Task 'release hardening'
.\scripts\get-project-memory.ps1 -Query 'cache' -Summary -Json

# Resolve an optional team policy profile and export high-risk-task evidence.
.\scripts\resolve-team-policy.ps1 -Profile default -Json
.\scripts\export-ueef-evidence.ps1 -RepositoryPath . -IncludeMemorySummary -Task 'release hardening' -Preview
.\scripts\export-ueef-evidence.ps1 -RepositoryPath . -OutputPath .\ueef-evidence.json -IncludeDiff

# Inspect the only tested adapter targets and estimate a proportional task budget.
.\scripts\get-assistant-adapters.ps1 -Json
.\scripts\get-task-budget-advice.ps1 -Tier T2 -ChangedFiles 6 -Json
```

On Unix, use `get-ueef-task-preflight.sh`, `write-project-memory.sh`, `get-project-memory.sh`, and `export-ueef-evidence.sh` for the bounded local equivalents, plus `get-diff-impact.sh` and `get-task-budget-advice.sh`. Unix preflight explicitly reports unsupported health rather than claiming capability or callable parity.

Unix preflight health is `UNSUPPORTED_ON_UNIX`; it is an honest fallback, not full Windows capability-health parity.
## Exact Codex installation

For Codex, UEEF installs exactly into the active Codex runtime. `CODEX_HOME` is required. The installer must create:

- `CODEX_HOME/AGENTS.md`
- `CODEX_HOME/ueef/codex`
- `CODEX_HOME/ueef/codex/UEEF-LOADER.md`
- `CODEX_HOME/ueef/UEEF-ACTIVE.json`

If `CODEX_HOME` is missing, `scripts/install-codex.ps1` and `scripts/install-codex.sh` must fail instead of installing to a fallback path.

## UI Selection

For theme, responsive, page, form, table, dashboard, dropdown, panel, modal, or interaction work, select the relevant modules in packs 46 and 47. Include pack 45 when identity, permissions, entitlements, employee access, public access, SaaS tenancy, or hybrid application boundaries are involved.
