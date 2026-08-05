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

## Spec Kit compatibility boundary

Current GitHub Spec Kit exposes a broader agent-facing command vocabulary than UEEF needs to copy directly: constitution, specify, clarify, plan, tasks, checklist, analyze, implement, task-to-issue conversion, and convergence. UEEF maps those ideas into owned artifacts and gates:

| Spec Kit concept | UEEF-native owner |
| --- | --- |
| Constitution / project principles | `constitution.md` and `01-constitution-and-principles.md` |
| Specify / requirements | `spec.md` and `02-specification-artifact.md` |
| Clarify | `clarifications.md` and `03-clarification-and-ambiguity.md` |
| Plan | `plan.md` and `04-technical-plan-translation.md` |
| Tasks | `tasks.md` and `05-task-breakdown-and-parallelization.md` |
| Checklist / analyze | `06-consistency-analysis-and-checklists.md` |
| Implement / converge | `07-implementation-and-convergence.md` |
| Extensions / presets / bundles | `08-extension-preset-bundle-governance.md` |
| Attribution | `09-third-party-attribution.md` and `docs/third-party/spec-kit-attribution.md` |

Do not install Spec Kit or copy its prompt files automatically. When the user asks for Spec Kit-style behavior, use UEEF's owned workflow unless they explicitly request the external CLI or upstream templates.
