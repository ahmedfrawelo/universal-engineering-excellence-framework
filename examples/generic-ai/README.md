# Generic AI Example

This example is for AGENTS-compatible tools that can read repository instructions but do not have a tested dedicated UEEF adapter.

## Supported expectation

Generic AI usage can follow UEEF instructions, examples, and validation scripts. It does not prove the same managed runtime, hook enforcement, model routing, or browser-control guarantees as the Codex runtime.

## Minimum workflow

1. Read the project handoff or root instructions.
2. Run source validation from the repository root:

```powershell
.\scripts\ueef-status.ps1
.\scripts\validate-framework.ps1
```

3. For a scoped task, select only the relevant framework modules.
4. For T2 or higher work, create and validate task evidence.
5. Before claiming completion, validate a completion audit.

## Runtime check examples

Use the sibling files in this directory for task-specific examples:

- `frontend-task-runtime-check.md`
- `backend-api-runtime-check.md`
- `database-runtime-check.md`
- `deploy-runtime-check.md`
- `runtime-check-example.md`

## Limit

Do not claim Codex managed runtime activation from generic AI execution. Generic AI can validate the source repository, but installed-runtime claims require the runtime-specific status path.
