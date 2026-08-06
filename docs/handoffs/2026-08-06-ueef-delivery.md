# UEEF Delivery Handoff - 2026-08-06

## Snapshot

- Source: `E:\MY DATA\div\universal-engineering-excellence-framework`
- Upstream: `https://github.com/ahmedfrawelo/universal-engineering-excellence-framework.git`
- Branch: `main`
- Version: `2.25.10`
- Installed Codex runtime: `D:\shared folder\codex-home\ueef\codex`
- Runtime mode: `managed-runtime`
- Authoritative revision: run `git rev-parse HEAD`; live Git output always wins.

UEEF is an installable engineering operating system for AI coding agents. It owns model and effort routing, bounded agent teamwork, token economy, spec-driven execution, repository intelligence, quality evidence, completion truthfulness, runtime synchronization, and browser safety. The source checkout is the editable owner; the installed runtime is a synchronized self-contained copy.

## Delivered behavior

### Repository intelligence

- The generated Repository Graph under `.ueef/repository-graph/` represents files, owners, architecture clusters, relationships, routing, and freshness.
- Architecture labels are disambiguated, repeated summary nodes are removed, and owner labels remain visible.
- Repository-scoped work checks graph freshness and performs a bounded query before broad inspection.

### Routing, execution, and token economy

- Work units resolve concrete models and supported efforts from the signed-in Codex App Server catalog.
- Route digests bind catalog, tier, work-unit ID, invocation, model pairs, execution spec, and token-economy contract.
- The direct dispatcher uses ephemeral App Server threads and verifies actual model and effort from host events.
- Smoke tests do not create visible sidebar tasks; visible task creation requires an explicit current request.
- T0/T1 default to minimal single-agent execution, T2 to a bounded sidecar, T3 to disjoint specialists when useful, and T4 to lead/workers/verifier when justified.
- The lead owns planning, integration, final verification, and completion. Worker output defaults to at most 12 bullets or 250 words.
- Token savings may not remove evidence, lower review, reuse stale state, or overlap write ownership.

### Spec-driven execution

- T2+ route recording creates a digest-bound minimum execution spec with outcome, acceptance criteria, owner paths, non-goals, budget, delegation policy, worker limit, output cap, and required evidence.
- Broad or durable work can use `.ueef/specs/<task-id>/` workflows.
- Spec validation checks budget, delegation, write boundaries, acceptance evidence, and convergence.

### Managed enforcement

- Hooks enforce route publication, verified dispatch, protected paths, visible-task authorization, evidence, progress, and completion.
- `functions.exec` supports strictly isolated route-recorder and direct-dispatcher wrappers.
- Quoted punctuation in route metadata is allowed while unquoted shell control operators remain denied.
- Documentation inside a patch is not treated as an executed destructive command; actual file-removal markers remain authorization-gated.
- Ambient `in-app-browser-context` metadata is excluded from frontend classification.
- Negated completion wording is not a completion claim.
- Optional plugin warnings do not make the required runtime inactive.

### Browser policy

- Browser work is explicit-task only and uses the user's existing Chrome window, profile, session, and a dedicated task tab.
- Do not create another browser, profile, window, context, in-app browser, IDE browser, or connector-created surface.
- Remote debugging is an explicitly authorized loopback-only last resort for the same proven target and may not inspect profile data.

## Ownership map

| Path | Purpose |
|---|---|
| `UEEF-LOADER.md` | Global source loader template. |
| `framework/_domains` | Fast domain navigation. |
| `framework/00-foundation` through `framework/21-framework-resources` | Stable numbered engineering packs. |
| `framework/19-agent-workflow/01-model-orchestration` | Tier, model, effort, topology, context, and token economy. |
| `framework/19-agent-workflow/02-skill-invocation-protocol` | Skill selection and verification. |
| `framework/19-agent-workflow/03-spec-driven-development` | Requirements, plans, tasks, evidence, and convergence. |
| `framework/20-repository-evolution` | Modernization, repository intelligence, and performance forensics. |
| `engines/repository-intelligence/graphify` | Embedded AST and graph engine plus UEEF adapter. |
| `scripts/codex-hooks` | Managed enforcement implementation. |
| `scripts` | Install, sync, routing, dispatch, tests, validators, and reports. |
| `config` | Routing, enforcement, capabilities, skills, adapters, and releases. |
| `docs` | Durable operating, architecture, release, and handoff records. |
| `.ueef` | Ignored task-local specs, evidence, audits, and generated graph artifacts. |

Do not rename or regroup stable packs without changing loaders, indexes, validators, release metadata, runtime synchronization, and all consumers together.

## Canonical entrypoints

- `framework/01-core/00-boot-loader.md`
- `framework/01-core/00-core-system.md`
- `framework/01-core/01-master-loader.md`
- `framework/03-runtime/00-runtime-sequence.md`
- `framework/12-delivery-quality/04-quality-gates/final-gate.md`
- `framework/MASTER_INDEX.md`
- `framework/DOMAIN_MAP.md`
- `config/enforcement-registry.json`
- `config/model-routing-policy.json`
- `release-manifest.json`
- `docs/releases/v2.25.10.md`

## Required sequence

1. Read `UEEF-LOADER.md` and run runtime status.
2. Keep `Loaded` exactly `boot-loader, core-system`.
3. Check repository-intelligence freshness and run a bounded query.
4. Classify T0-T4 and record intent, agent route, browser reason, acceptance, owners, and non-goals.
5. Publish and execute the exact current host route.
6. Inspect Git, architecture, ownership, and patterns before editing.
7. For T2+, validate evidence and use a durable spec when breadth requires it.
8. Test requested behavior and run proportional gates.
9. Synchronize source to runtime and verify installed status.
10. Validate a schema-version-2 completion audit before COMPLETE or 100 percent.
11. Inspect Git again before staging, commit, push, or release.

## Authoritative commands

```powershell
Set-Location 'E:\MY DATA\div\universal-engineering-excellence-framework'
git status --short
git rev-list --left-right --count origin/main...HEAD
& .\scripts\validate-framework.ps1
& .\scripts\test-script-syntax.ps1
& .\scripts\test-managed-enforcement.ps1
& .\scripts\test-spec-workflow.ps1
& .\scripts\sync-runtime.ps1 -CodexHome 'D:\shared folder\codex-home' -Agent codex -BackupRoot 'D:\shared folder\codex-home-backups'
& 'D:\shared folder\codex-home\ueef\codex\scripts\ueef-status.ps1'
```

Installed status must include `Overall: ACTIVE`, `Managed enforcement: PASS`, `Managed enforcement effective: PASS`, `Runtime drift: PASS`, and `Runtime source revision: PASS`.

For T2+ evidence and closure:

```powershell
& .\scripts\new-task-evidence.ps1 -TaskId <task-id> -Tier T2 -SelectedDomain <domains> -OutputPath .\.ueef\evidence\<task-id>.json
& .\scripts\validate-task-evidence.ps1 -Tier T2 -SelectedDomain <domains> -EvidencePath .\.ueef\evidence\<task-id>.json
& .\scripts\validate-completion-audit.ps1 -Path .\.ueef\completion-audit\<task-id>.json
```

## Current delivery change set

- catalog-backed routing and token-economy contracts;
- automatic T2+ execution specs;
- bounded Leader/Worker topology and output caps;
- ephemeral routing and hook smoke tests;
- verified App Server model/effort receipts;
- explicit authorization for visible task creation;
- isolated recorder and dispatcher support through `functions.exec`;
- quoted shell metadata parsing without weakening compound-command denial;
- ambient UI metadata exclusion from task classification;
- patch documentation versus executed destructive-command separation;
- runtime source-revision and enforcement health checks;
- graph label disambiguation and duplicate-summary removal;
- focused routing, dispatch, enforcement, spec, graph, and syntax tests.

## Boundaries and delivery facts

- UEEF cannot resolve provider capacity or rotate accounts, cookies, profiles, credentials, or browser sessions.
- Generic tests do not prove an untested requested behavior.
- Source validation, installed runtime, browser behavior, commit, push, CI, tag, GitHub Release, and deployment are separate facts.
- `.ueef` artifacts are ignored and task-local; copy durable evidence into tracked documentation when another clone needs it.
- Preserve worktree changes; never reset or clean them away.
- Inspect every change and run `git diff --check`, `git diff --cached --check`, and relevant tests before commit.
- This handoff does not claim a GitHub Release. Release publication requires a separate explicit request and exact-commit CI/tag verification.

## Acceptance checklist

- [ ] Inspect worktree, divergence, and `git show --stat --oneline HEAD`.
- [ ] Run source validation and focused enforcement tests.
- [ ] Verify graph freshness and bounded query behavior.
- [ ] Synchronize and verify installed runtime.
- [ ] Validate required evidence and completion audit.
- [ ] Report commit, push, release, and runtime sync independently.

This handoff is accepted only when current repository commands corroborate it.
