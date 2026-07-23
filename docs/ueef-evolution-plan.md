# UEEF Evolution Plan

## Outcome

Evolve UEEF into a fast, evidence-driven engineering runtime that selects only the guidance, skills, tools, agents, and verification required by a task. It must improve delivery quality without turning routine work into a slow or expensive checklist exercise.

## Scope and boundaries

This plan covers the framework content, global runtime installer, agent/task routing, skills and MCP capability management, verification, release process, and operational diagnostics.

It does not replace Codex, install untrusted tools automatically, collect user code or credentials, or make every task use every pack. Existing user configuration remains preserved unless an explicit migration is both reversible and verified.

## Current baseline (2026-07-23)

- UEEF runtime version `2.11.0` is `ACTIVE` and has no drift.
- The source is clean at `2155799` and contains 62 framework packs and 78 scripts.
- Core and AI environment profiles are `READY`.
- The full audit passes, including runtime hardening.
- Pack 60 provides UEEF's Spec-Driven Development workflow. It is compatible in intent with Spec Kit, but is not a bundled copy of the upstream project.
- The upstream references considered for this evolution are GitHub's Spec Kit and obra/Superpowers. Their public ideas will be adapted only through UEEF-owned contracts, attribution, and tests; neither project is copied wholesale or installed automatically.

## Product requirements

| ID | Requirement | Evidence of completion |
| --- | --- | --- |
| R1 | Task routing selects the smallest useful module, skill, model tier, and tool set from explicit task evidence. | Deterministic routing tests and explainable decision record. |
| R2 | Specification-first work has first-class artifacts for requirements, clarification, plan, tasks, and acceptance evidence. | End-to-end fixture proving traceability from request to verification. |
| R3 | Installed skills and MCP servers have an explicit capability registry, health state, provenance, version/pin, and safe fallback. | Registry validation plus offline/failure fixtures. |
| R4 | Runtime installation, update, rollback, and recovery are transactional, idempotent, fast, and preserve user-owned configuration. | Fresh install, upgrade, rollback, drift, and recovery tests. |
| R5 | Quality gates are risk-proportionate: routine work is quick; high-risk work receives deeper independent verification. | Time-budget tests and risk-tier gate matrix. |
| R6 | The runtime reports actionable diagnostics rather than contradictory or stale status. | Machine-readable health report and fault-injection tests. |
| R7 | Releases are reproducible, versioned, documented, and verified on Windows and Unix. | Release manifest, clean-install test, and cross-platform CI evidence. |
| R8 | The framework remains secure by default: no secret collection, unsafe shell interpolation, path escape, silent remote installation, or destructive cleanup. | Security regression suite and review gate. |

## Architecture target

```text
Task request
  -> task classifier + context map
  -> capability resolver (packs, skills, MCPs, tools, agent tier)
  -> execution contract (plan, tasks, evidence, cost/time budget)
  -> runtime adapters (Codex, scripts, skills, MCP clients)
  -> proportional gates + diagnostics
  -> signed-off release/runtime state
```

Each layer has one owner and a narrow contract. The resolver must degrade safely when an optional skill or MCP is unavailable; it must never invent a capability or claim it ran a tool that is not callable.

## Delivery roadmap

### Phase 1 — Spec Kit-strength workflow foundation

Deliver a unified project artifact format for `spec`, `clarifications`, `plan`, `tasks`, and `evidence`; add a generator and validator; map the artifacts to Pack 60 without copying upstream branding or code. Add fixtures for a small, medium, and high-risk task.

Success: a task can be created, clarified, planned, implemented, and verified with a traceable artifact chain.

The first deliverable is an opt-in, project-local `.ueef/specs/<id>` workflow with generator and Draft/Ready validator. It adopts Spec Kit's useful progression (principles, specification, plan, tasks, implementation evidence, convergence) while preserving UEEF's safety and cross-platform runtime ownership. Spec Kit also demonstrates useful extension, preset, and role-bundle concepts; these will be added only after a local manifest, provenance, permission, rollback, and compatibility contract exists. [Spec Kit](https://github.com/github/spec-kit) is the upstream reference.

### Phase 2 — Intelligent routing and economy

Replace broad default loading with a deterministic task profile and capability resolver. It selects the lowest capable agent tier, only relevant packs, and a bounded verification level. Cache repository context using content hashes and invalidate only on relevant changes.

Success: routing is explainable, repeatable, and measurably reduces unnecessary file/tool loading for routine work.

### Superpowers adaptation policy

Superpowers is a composable agent-skill methodology with useful practices such as brainstorming, test-first work, systematic debugging, plan execution, and independent review. UEEF will not stack a second global instruction system on top of itself. Instead it will evaluate each practice as an optional, UEEF-owned workflow module with explicit trigger, expected benefit, token/time budget, compatibility, and verification. The first candidates are: structured brainstorming for ambiguous product work, evidence-led debugging for regressions, test-first implementation for behavior changes, and independent review for high-risk changes. [Superpowers](https://github.com/obra/superpowers) is the upstream reference.

## Proportional tool policy

Tools, MCPs, skills, subagents, and heavy quality gates are **not** mandatory on every task. Every task always receives the lightweight core: scope check, safe file ownership, and a result appropriate to the request. Additional capabilities are selected only when their trigger is present.

| Task class | Default | Escalate when |
| --- | --- | --- |
| T0: answer, single lookup, simple text edit | Core only; no durable artifacts or delegation. | User requests a tool, current data is needed, or a risk trigger appears. |
| T1: bounded code or docs change | Relevant repository inspection, focused test, and minimal relevant skill/tool. | Shared contract, security, migration, or unclear acceptance criteria. |
| T2: multi-file feature or integration | Pack 60 workflow when ambiguity/durability warrants it; scoped gates; bounded sidecar only with independent value. | External state, multiple systems, or meaningful rollback risk. |
| T3/T4: security, payment, production, migration, destructive, or privacy work | Full evidence chain, explicit route, independent verification, and relevant MCP/skill health checks. | Never downgrade without recorded accountable acceptance. |

MCP use is capability-driven: configuration alone is not enough. A server must be both enabled and callable for a selected task; otherwise UEEF reports a safe fallback rather than retrying blindly or claiming success.

### Phase 3 — Skills, MCPs, and tool reliability

Create a declarative registry for skills and MCP servers: source, version/pin, install method, permissions, required environment, health probe, fallback, and consumer packs. Add an installer/doctor that distinguishes configured, installed, enabled, callable, and unavailable.

Success: the UI and runtime cannot confuse a config entry with an active callable server; every capability has a verified state.

### Phase 4 — Runtime resilience and diagnostics

Make status, audit, sync, and rollback share one machine-readable health model. Add lock/transaction observability, timeout classification, retry policy for transient failures, cleanup guarantees, and concise human summaries.

Success: a transient failure is reported as transient with evidence; a genuine failure includes its component, cause, recovery action, and safe next command.

### Phase 5 — Continuous assurance and release engineering

Add CI matrices for Windows and Unix, deterministic test fixtures, performance budgets, release notes generation, clean-room install/upgrade tests, and a compatibility matrix for Codex versions and operating systems.

Success: every release is installable from a clean machine, reproducible, and backed by a compact evidence report.

### Phase 6 — Adoption and iterative hardening

Pilot the new workflow on representative frontend, backend, documentation, and installer tasks. Measure route accuracy, gate duration, failure recovery, and user intervention; tighten only the rules supported by evidence.

Success: the framework becomes more reliable and faster in real tasks without increasing routine-task friction.

## Performance and cost budgets

- T0/T1 route selection: target under 2 seconds after context cache warm-up.
- Routine verification: target under 15 seconds; deeper gates run only when the task risk warrants them.
- Runtime quick status: target under 10 seconds.
- Full assurance: show individual stage duration and retain a baseline to catch regressions.
- Context loading: load the boot loader, core system, and selected modules only; report selection reasons.
- Delegation: use bounded specialists only when the work is independent and verification benefit outweighs coordination cost.

Budgets are targets until benchmark fixtures establish platform baselines; they must never hide failed or skipped safety checks.

## Acceptance gates

1. Every new runtime feature has a documented owner, threat model, rollback behavior, and test fixture.
2. A capability must not be shown as active until its health probe succeeds in the current environment.
3. A release must pass source validation, installer tests, runtime hardening, cross-platform syntax checks, clean-install verification, and drift detection.
4. Diagnostics must return both concise human output and machine-readable structured output.
5. Routine tasks must demonstrate a lower or equal context/tool cost than the current baseline while preserving the relevant gate coverage.
6. No user configuration, credentials, browser state, project files, or unrelated plugins may be overwritten or removed by a normal upgrade.

## Risks and controls

| Risk | Control |
| --- | --- |
| Framework becomes slower because every rule is loaded | Deterministic profile selection, caches, and time budgets. |
| MCP configuration is mistaken for availability | Separate configured/installed/enabled/callable states and probe each. |
| Automation damages user state | Transactional writes, explicit ownership boundaries, backup/rollback tests. |
| Tool or model changes break integrations | Version pins, capability contracts, compatibility fixtures, safe fallbacks. |
| Over-engineering adds complexity without value | Phase exit metrics and pilot evidence before expanding the system. |

## Implementation order

1. Create the Pack 60 artifact generator, schema, and validator.
2. Add task profile and capability registry schemas with tests.
3. Implement MCP/skill doctor and structured health report.
4. Consolidate runtime status/audit/sync health data and transient-failure handling.
5. Add benchmarks, CI matrix, clean-room install tests, and release evidence.
6. Pilot, measure, and refine the defaults before making new behavior mandatory.

## Evidence ledger

Each phase must record: source commit, changed contracts, test commands and results, timing, migration/rollback evidence, known limitations, and release decision. A phase is not complete merely because its documentation exists.
