# UEEF Delivery Handoff - 2026-08-08

## Snapshot

- Source: `E:\MY DATA\div\universal-engineering-excellence-framework`
- Upstream: `https://github.com/ahmedfrawelo/universal-engineering-excellence-framework.git`
- Branch: `main`
- Version: `2.26.0`
- Installed Codex runtime: `D:\shared folder\codex-home\ueef\codex`
- Runtime mode: `managed-runtime`
- Authoritative revision: run `git rev-parse HEAD`; live Git output always wins.

## Delivered behavior

UEEF now owns an executable specification workflow rather than only Markdown workflow guidance.

- `engines/spec-workflow/upstream/spec-kit/` contains an unmodified GitHub Spec Kit `v0.16.1` source snapshot.
- `engines/spec-workflow/UPSTREAM.json` pins the commit, license, copied roots, file count, and aggregate digest.
- `engines/spec-workflow/ueef/ueef_spec_workflow/` owns validation, state, scheduling, policy, adapters, and the CLI.
- `.ueef/specs/<id>/task-graph.json` is generated and validated with the existing spec artifacts.
- Execution state is atomic, revision guarded, graph-digest bound, resumable, retry bounded, and evidence backed.
- Scheduling reserves conflict-free waves before dispatch, isolates risk-3 work, accounts for active token reservations and worker slots, and grows or shrinks the desired host team from actual ready work.
- Host adapters emit bounded dispatch contracts. They do not create hidden tasks or execute upstream shell steps.

## Security and update boundary

- The upstream snapshot is not modified in place. Refresh it by replacing the snapshot, updating `UPSTREAM.json`, preserving the MIT license, and rerunning upstream and UEEF tests.
- The UEEF CLI has no workflow-run command. `upstream-validate` is validation only; shell execution is always false.
- Community workflows, custom steps, extensions, presets, and bundles remain opt-in external code and are not loaded automatically.
- Core scheduling has no third-party runtime dependencies. Optional upstream validation dependencies are locked in `engines/spec-workflow/uv.lock`.

## Authoritative commands

```powershell
Set-Location 'E:\MY DATA\div\universal-engineering-excellence-framework'
& .\scripts\invoke-spec-workflow-engine.ps1 upstream-status
& .\scripts\test-spec-workflow-engine.ps1
& .\scripts\test-spec-workflow.ps1
& .\scripts\validate-framework.ps1
& .\scripts\test-release-consistency.ps1
& .\scripts\sync-runtime.ps1 -CodexHome 'D:\shared folder\codex-home' -Agent codex -BackupRoot 'D:\shared folder\codex-home-backups'
& 'D:\shared folder\codex-home\ueef\codex\scripts\ueef-status.ps1'
```

For the locked cross-platform engine job:

```powershell
uv sync --project .\engines\spec-workflow --group dev --extra upstream --locked
uv run --project .\engines\spec-workflow --frozen pytest
```

## Release completion

Before claiming release completion, require the exact commit to pass every GitHub Actions job, publish annotated tag `v2.26.0`, publish a non-draft GitHub Release, synchronize the Codex runtime from that exact source, and require runtime `Overall: ACTIVE`, `Runtime drift: PASS`, and `Runtime source revision: PASS`.
