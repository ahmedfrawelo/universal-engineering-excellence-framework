# Spec-Driven Development

Pack 60 turns ambiguous or high-impact work into a governed specification flow before implementation. Its governing rules and execution engine are UEEF-owned. A pinned, unmodified GitHub Spec Kit source snapshot is retained separately only for manual comparison, provenance, and license review; UEEF runtime code does not read or import it.

Use this pack when a feature, redesign, migration, integration, platform workflow, or agent behavior change needs durable requirements, acceptance criteria, traceability, or task decomposition.

## Route-bound executable workflow

For a project-local workflow, generate artifacts under `.ueef/specs/<id>`:

```powershell
./scripts/new-spec-workflow.ps1 -Id my-feature -Root . -RoutePath <fresh-route.json>
./scripts/validate-spec-workflow.ps1 -Path .\.ueef\specs\my-feature -Mode Draft
./scripts/invoke-spec-workflow-engine.ps1 compile --tasks .\.ueef\specs\my-feature\tasks.md --workflow-id my-feature --route <fresh-route.json> --output .\.ueef\specs\my-feature\task-graph.json
./scripts/validate-spec-workflow.ps1 -Path .\.ueef\specs\my-feature -Mode Ready -RoutePath <fresh-route.json>
./scripts/invoke-spec-workflow-engine.ps1 init --graph .\.ueef\specs\my-feature\task-graph.json --state .\.ueef\specs\my-feature\execution-state.json
./scripts/invoke-spec-workflow-engine.ps1 schedule --graph .\.ueef\specs\my-feature\task-graph.json --state .\.ueef\specs\my-feature\execution-state.json --adapter codex
```

`Draft` can exist before routing. `Ready` requires a schema-v2 graph deterministically compiled from `tasks.md` and the validated route, completed placeholders, matching route budgets, and acceptance evidence. Manual graph edits or stale compilation fail validation. The execution state is created only by explicit `init` or the host-cycle facade.

## Spec Kit comparison boundary

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

The pinned reference snapshot is never a runtime command surface or validation dependency. Do not install or activate Spec Kit prompts, community steps, extensions, or bundles through UEEF. Use UEEF's owned artifacts, scheduler, and Codex production facade. Reference updates are reviewed manually with `scripts/review-spec-kit-update.ps1`; no bridge imports or executes the snapshot.
