# UEEF Architecture

UEEF is a Markdown-first engineering operating system. It is deliberately
split into a source checkout, a managed runtime, and the small executable
contracts that connect them. Agents should load only the contracts relevant to
the current task; the repository remains inspectable without a proprietary
loader.

## Layered model

| Layer | Responsibility | Authoritative artifacts |
| --- | --- | --- |
| Source | Human-reviewed framework packs, policies, scripts, tests, manifests, and release notes | `framework/`, `scripts/`, `config/`, root docs |
| Runtime | A transactional, tracked-file copy installed under the selected Codex home | `ueef/<agent>/`, `UEEF-ACTIVE.json`, managed `AGENTS.md` block |
| Activation | Proves that the runtime points at the intended source and loader hash | `scripts/sync-runtime.ps1`, `scripts/ueef-status.ps1`, activation gate |
| Task control | Classifies scope/risk and chooses capabilities, gates, and evidence | `get-ueef-task-classification.ps1`, `get-ueef-task-preflight.ps1`, selectors |
| Assurance | Validates source structure, runtime integrity, release policy, and regressions | `validate-framework.ps1`, `ueef-audit.ps1`, nested contract tests |

The source is the authority. A managed runtime is disposable and must never
be edited as a second source of truth. Runtime synchronization copies only
tracked, policy-approved release files, rejects unsafe paths and reparse
points, validates before activation, and rolls back the previous state when a
transaction fails.

## Task lifecycle

Every non-trivial task follows this flow:

1. Read the loader and applicable handoff/context.
2. Classify omitted signals from task text while preserving explicit inputs.
3. Select an agent route (`T0` through `T4`) with a proportional reasoning
   ceiling and an evidence requirement.
4. Select a capability profile and quality gates from the route and the task
   domain. T0 stays core-only; T1 adds focused change/testing gates; T2+
   adds guardian and environment contracts.
5. Run the work, recording decisions and external-state assumptions.
6. Run focused verification, then the full source/runtime audit at release or
   contract boundaries.

`get-ueef-task-preflight.ps1` reports both task readiness and activation
authority. `ACTIVE_RUNTIME` means an installed runtime is validated;
`SOURCE_VALIDATED` means repository maintenance is safe but does not claim that
the host runtime has been activated.

## Packs and selectors

Framework packs are numbered for stable loading order. Core and runtime packs
define boot, activation, routing, and state contracts. Domain packs provide
focused engineering guidance. Quality-gate files are executable policy
checklists: selectors emit paths, and the validator proves that emitted paths
exist. New packs must update the master index, release manifest, acceptance
tests, and relevant selectors rather than relying on filename discovery.

## State, drift, and boundaries

`UEEF-ACTIVE.json` records the runtime path, source revision, loader hash,
required checks, and routing contract version. Managed status fails closed when
the state is missing, inactive, stale, tampered, or drifted from the tracked
source. A source checkout reports `SOURCE_VALIDATED` with AGENTS and active
state marked `NOT_APPLICABLE`; this prevents a healthy repository from being
misreported as an active installation.

Capability health distinguishes configured, callable, unavailable, and
optional capabilities. A missing optional integration produces a warning and
must have a documented fallback. Secrets and credentials are never copied into
the runtime release set or evidence reports.

## Cross-platform contract

PowerShell is the primary Windows implementation. POSIX shell/Node entrypoints
provide the supported Unix surface where parity exists, while explicitly
reporting unsupported capability-health or browser integrations instead of
pretending they are available. Cross-platform changes must update both
implementations or document the intentional boundary and its fallback.
