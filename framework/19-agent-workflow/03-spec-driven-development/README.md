# Spec-Driven Development

Pack 60 turns ambiguous or high-impact work into a governed specification flow before implementation. Its governing rules are UEEF-owned. A pinned, unmodified GitHub Spec Kit source snapshot is available to the separate execution engine for provenance and compatibility validation.

Use this pack when a feature, redesign, migration, integration, platform workflow, or agent behavior change needs durable requirements, acceptance criteria, traceability, or task decomposition.

## Optional executable workflow

For a project-local workflow, generate artifacts under `.ueef/specs/<id>`:

```powershell
./scripts/new-spec-workflow.ps1 -Id my-feature -Root .
./scripts/validate-spec-workflow.ps1 -Path .\.ueef\specs\my-feature -Mode Draft
./scripts/validate-spec-workflow.ps1 -Path .\.ueef\specs\my-feature -Mode Ready
./scripts/invoke-spec-workflow-engine.ps1 init --graph .\.ueef\specs\my-feature\task-graph.json --state .\.ueef\specs\my-feature\execution-state.json
./scripts/invoke-spec-workflow-engine.ps1 schedule --graph .\.ueef\specs\my-feature\task-graph.json --state .\.ueef\specs\my-feature\execution-state.json --adapter codex
```

`Draft` validates the artifact structure and task graph while placeholders remain. `Ready` also requires completed placeholders, task-ID consistency, matching worker policy, and recorded acceptance evidence. The execution state is created only by the explicit `init` command. The workflow is opt-in: small, low-risk tasks should not generate durable artifacts unless the user asks for them or the task's risk and ambiguity justify them.

## Spec Kit compatibility boundary

Current GitHub Spec Kit exposes a broader agent-facing command vocabulary than UEEF needs to copy directly: constitution, specify, clarify, plan, tasks, checklist, analyze, implement, task-to-issue conversion, and convergence. UEEF maps those ideas into owned artifacts and gates:

| Spec Kit concept | UEEF-native owner |
| --- | --- |
| Constitution / project principles | `constitution.md` and `01-constitution-and-principles.md` |
| Specify / requirements | `spec.md` and `02-specification-artifact.md` |
| Clarify | `clarifications.md` and `03-clarification-and-ambiguity.md` |
| Plan | `plan.md` and `04-technical-plan-translation.md` |
| Tasks | `tasks.md` and `05-task-breakdown-and-parallelization.md` |
| Task graph / waves / resume | `task-graph.json` and `engines/spec-workflow/ueef/` |
| Checklist / analyze | `06-consistency-analysis-and-checklists.md` |
| Implement / converge | `07-implementation-and-convergence.md` |
| Extensions / presets / bundles | `08-extension-preset-bundle-governance.md` |
| Attribution | `09-third-party-attribution.md` and `docs/third-party/spec-kit-attribution.md` |

The pinned upstream source snapshot is never an automatic command surface. Do not install or activate Spec Kit prompts, community steps, extensions, or bundles automatically. Use UEEF's owned artifacts and scheduler; use the upstream bridge only for explicit compatibility validation. The UEEF CLI has no workflow execution or shell execution command.
