# Spec-Driven Development

Pack 60 turns ambiguous or high-impact work into a governed specification flow before implementation. It is inspired by GitHub Spec Kit's public specification-driven development methodology, adapted into UEEF rules without copying Spec Kit templates, slash commands, or source files.

Use this pack when a feature, redesign, migration, integration, platform workflow, or agent behavior change needs durable requirements, acceptance criteria, traceability, or task decomposition.

## Optional executable workflow

For a project-local workflow, generate artifacts under `.ueef/specs/<id>`:

```powershell
./scripts/new-spec-workflow.ps1 -Id my-feature -Root .
./scripts/validate-spec-workflow.ps1 -Path .\.ueef\specs\my-feature -Mode Draft
./scripts/validate-spec-workflow.ps1 -Path .\.ueef\specs\my-feature -Mode Ready
```

`Draft` validates the artifact structure while placeholders remain. `Ready` also requires completed placeholders and recorded acceptance evidence. The workflow is opt-in: small, low-risk tasks should not generate durable artifacts unless the user asks for them or the task's risk and ambiguity justify them.
