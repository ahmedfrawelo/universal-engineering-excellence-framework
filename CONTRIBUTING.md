# Contributing

UEEF changes must improve enforceable engineering behavior, not only add prose. A contribution is ready when it is scoped, owned, validated, and safe to install into the target runtime.

## Contribution rules

1. Preserve the user's worktree. Check `git status --short` before staging or committing, and never reset, clean, delete, push, release, or sync runtime unless that action is explicitly in scope.
2. Keep changes in the correct owner: framework packs under `framework/`, runtime scripts under `scripts/`, configuration under `config/`, examples under `examples/`, and generated evidence under `.ueef/`.
3. Do not add placeholders, empty files, duplicate guidance, or broad motivational text. Every new instruction should tell an agent what to decide, where to act, and what evidence proves completion.
4. Prefer small reviewable slices. Separate behavior changes from documentation-only changes unless the documentation is required to explain the behavior.
5. Reuse existing scripts, templates, registries, and validation patterns before adding a parallel mechanism.

## Required local checks

For normal source changes run the narrow relevant tests first, then the framework gate:

```powershell
.\scripts\validate-framework.ps1
git status --short
```

For T2 or higher UEEF tasks, create and validate task evidence:

```powershell
.\scripts\new-task-evidence.ps1 -TaskId <task-id> -Tier T2 -SelectedDomain <domain> -OutputPath .\.ueef\evidence\<task-id>.json
.\scripts\validate-task-evidence.ps1 -Tier T2 -SelectedDomain <domain> -EvidencePath .\.ueef\evidence\<task-id>.json
```

Before claiming completion, validate a completion audit:

```powershell
.\scripts\validate-completion-audit.ps1 -Path .\.ueef\completion-audit\<task-id>.json
```

## Runtime sync rule

Source validation does not prove the installed Codex runtime is updated. After a source change that should affect the Codex runtime, sync explicitly and verify the installed runtime:

```powershell
.\scripts\sync-runtime.ps1 -CodexHome "D:\shared folder\codex-home" -Agent codex -BackupRoot "D:\shared folder\codex-home-backups"
& "D:\shared folder\codex-home\ueef\codex\scripts\ueef-status.ps1"
```

The runtime is active only when the installed status reports `Overall: ACTIVE`, `Runtime drift: PASS`, and `Runtime source revision: PASS`.

## Pull request or commit description

Use Conventional Commits. The description should state:

- what changed;
- why it changed;
- which commands passed;
- which behavior was verified;
- what remains unverified, if anything.
