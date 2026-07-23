# Quick Start

1. Clone the repository: git clone https://github.com/ahmedfrawelo/universal-engineering-excellence-framework.git.
2. Enter it: cd universal-engineering-excellence-framework.
3. Install for Codex: .\scripts\install-codex.ps1 on Windows or ./scripts/install-codex.sh on Unix.
4. Verify: run .\scripts\validate-framework.ps1.
5. First use: have Codex read the installed `UEEF-LOADER.md` before the task. It loads `boot-loader` and `core-system`, then uses the master loader to select task-specific modules.

UEEF is active when the assistant inspects the project, detects stack and architecture, produces a plan, applies relevant modules, and runs quality gates before finishing.

The current release is 2.13.0. See [VERSION.md](VERSION.md) for the version policy and [docs/releases](docs/releases/) for individual release notes. Codex installation also installs the pinned `design-brief` and `frontend-design` skills when they are missing.

## Runtime Check

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
```
## Exact Codex installation

For Codex, UEEF installs exactly into the active Codex runtime. `CODEX_HOME` is required. The installer must create:

- `CODEX_HOME/AGENTS.md`
- `CODEX_HOME/ueef/codex`
- `CODEX_HOME/ueef/codex/UEEF-LOADER.md`
- `CODEX_HOME/ueef/UEEF-ACTIVE.json`

If `CODEX_HOME` is missing, `scripts/install-codex.ps1` and `scripts/install-codex.sh` must fail instead of installing to a fallback path.

## UI Selection

For theme, responsive, page, form, table, dashboard, dropdown, panel, modal, or interaction work, select the relevant modules in packs 46 and 47. Include pack 45 when identity, permissions, entitlements, employee access, public access, SaaS tenancy, or hybrid application boundaries are involved.
