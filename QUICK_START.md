# Quick Start

1. Clone the repository: git clone https://github.com/ahmedfrawelo/universal-engineering-excellence-framework.git.
2. Enter it: cd universal-engineering-excellence-framework.
3. Install for Codex: .\scripts\install-codex.ps1 on Windows or ./scripts/install-codex.sh on Unix.
4. Verify: run .\scripts\validate-framework.ps1.
5. First use: have Codex read the installed `UEEF-LOADER.md` before the task. It loads `boot-loader` and `core-system`, then uses the master loader to select task-specific modules.

UEEF is active when the assistant inspects the project, detects stack and architecture, produces a plan, applies relevant modules, and runs quality gates before finishing.

The current release is 2.14.1. See [VERSION.md](VERSION.md) for the version policy and [docs/releases](docs/releases/) for individual release notes. Codex installation also installs the pinned `design-brief` and `frontend-design` skills when they are missing.

## Runtime Check

Browser work = your existing Chrome only; never a second browser.

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
## Exact Codex installation

For Codex, UEEF installs exactly into the active Codex runtime. `CODEX_HOME` is required. The installer must create:

- `CODEX_HOME/AGENTS.md`
- `CODEX_HOME/ueef/codex`
- `CODEX_HOME/ueef/codex/UEEF-LOADER.md`
- `CODEX_HOME/ueef/UEEF-ACTIVE.json`

If `CODEX_HOME` is missing, `scripts/install-codex.ps1` and `scripts/install-codex.sh` must fail instead of installing to a fallback path.

## UI Selection

For theme, responsive, page, form, table, dashboard, dropdown, panel, modal, or interaction work, select the relevant modules in packs 46 and 47. Include pack 45 when identity, permissions, entitlements, employee access, public access, SaaS tenancy, or hybrid application boundaries are involved.
