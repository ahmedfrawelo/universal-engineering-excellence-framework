# UEEF Spec Workflow Engine

This engine compiles a canonical specification task plan, persists fenced execution, coordinates explicit host lifecycles, and requires independent verification before a schema-v2 workflow can finish.

## Ownership and provenance

- `upstream/spec-kit/` is an unmodified GitHub Spec Kit `v0.16.1` reference snapshot at commit `ad4104b56c219b0a27bac06547d1a3c7d6a0dbd6`, retained only for manual comparison, provenance, and licensing.
- Schema-v2 `UPSTREAM.json` records provenance and a length-prefixed aggregate digest; `scripts/verify-spec-workflow-upstream.mjs` validates the complete snapshot tree and manifest without executing snapshot content.
- `ueef/ueef_spec_workflow/` owns UEEF compilation, policy, state, scheduling, lifecycle, migration, convergence, verification, and benchmarks.
- The UEEF runtime never reads, imports, or executes the reference snapshot. It has no Spec Kit runtime bridge.

## Canonical workflow

`tasks.md` is the only authored execution plan. `compile` combines it with a fresh validated UEEF route and generates a schema-v2 `task-graph.json` bound to the source, route, and execution-spec digests. `--check` detects both source drift and manual graph edits.

```powershell
scripts\invoke-spec-workflow-engine.ps1 compile --tasks tasks.md --workflow-id my-flow --route route.json --output task-graph.json
scripts\invoke-spec-workflow-engine.ps1 compile --tasks tasks.md --workflow-id my-flow --route route.json --output task-graph.json --check
scripts\validate-spec-workflow.ps1 -Path .ueef\specs\my-flow -Mode Ready -RoutePath route.json
```

A v1 graph remains readable only for migration and Draft compatibility. It cannot pass `Ready` or use fence-safe v2 receipts.

`prepare` is the mandatory end-to-end readiness entrypoint. It refuses execution until
constitution, specification, clarifications, plan, tasks, route, and compiled graph are
present, resolved, placeholder-free, and mutually consistent.

## Operator control and dynamic team lifecycle

`pause` and `resume` persist an operator-owned workflow state without changing execution
identity or discarding attempts/evidence. A paused workflow cannot reserve new work.
The team manager may rebalance by stealing only an unstarted `RESERVED` task from an
unavailable worker. Reassignment creates a new attempt and fence; dispatched/running work
is never stolen.

## Hierarchies and safe UEEF composition

`hierarchy` validates parent/subfeature graphs, rejects cycles, and rolls `DONE` upward only
when every descendant has a trusted-verifier HMAC receipt bound to the feature, workflow,
graph, execution, evidence, and diff. A self-authored digest or `verified: true` cannot
complete a hierarchy. `expand-workflow` supports a
bounded fail-closed subset of declarative condition, fan-out/fan-in, and loop constructs.
Shell, command, prompt, unknown, or unbounded steps are rejected.

`resolve-customizations` resolves extension, preset, and bundle manifests deterministically.
Every item requires source, version, SHA-256, permissions, and rollback metadata. A
customization cannot widen the validated worker cap or request shell, credential, or
unbounded-network permission.

The production engine is reference-independent: its Python package and workflow entrypoints
neither import, execute, nor read the vendored reference implementation. Only the framework
integrity verifier and `scripts/review-spec-kit-update.ps1` may inspect a reference snapshot;
neither can activate one. UEEF-native parity is semantic rather than format-wide:

| Reference capability | UEEF-native production semantic |
|---|---|
| conditions | named, explicitly supplied booleans; unknown expressions fail closed |
| while / do-while | statically bounded expansion, at most 20 iterations |
| fan-out / fan-in | at most 16 explicit branches followed by dependency-joined gates |
| workflow overlays | bounded anchor edits with deterministic layer precedence and digest |
| extensions / presets | permission- and route-clamped catalog items |
| bundles | dependency-expanded, cycle-checked activation groups |
| catalogs | bounded sources with install-allowed or discovery-only policy |

Executable steps, arbitrary expressions, runtime plug-in imports, and unbounded expansion are
not compatibility gaps: they are deliberately outside the production grammar.

The local catalog lifecycle is fully owned by UEEF. `catalog-query` provides bounded
list/search/info discovery. `catalog-registry` atomically initializes, validates, reconciles,
enables/disables and prioritizes sources, and selects items. `catalog-maintain` uses a
cross-process lock plus expected-digest CAS to add/update/remove source or item metadata;
item mutations bind `(id, sourceId)`. `catalog-build` resolves the selected dependency graph
under validated route ceilings. These commands never fetch or execute plug-in code; trusted
package install/update/activation remains the separately attested `PackageStore` lifecycle.

Host status distinguishes `VERIFIED_RUNTIME` from `CONTRACT_ONLY`; an adapter name alone
is never runtime evidence.
The generic adapter has an executable bridge at `scripts/invoke-spec-workflow-generic-host.mjs`.
It runs only an explicitly supplied command, sends one bounded contract on stdin, and accepts
only one identity-matching schema-v2 receipt.

Template composition is content-addressed and declarative. It overlays
`project > preset > extension > core`, rejects traversal, symlinks, executable content,
and bounded-resource violations, then emits one canonical digest. Packages are staged and
verified before an atomic activation pointer change; activation history supports verified
rollback without mutating installed versions.
Package commands are fail-closed by default: they require a schema-v1 local trust policy
containing `packageSignerKeys` and accept only identity-bound, unexpired schema-v2 provenance
attestations. The store persists a monotonic signer watermark to reject rollback and
same-sequence equivocation. `--legacy-unsigned` is an explicit compatibility mode and never
represents trusted production.

```powershell
scripts\invoke-spec-workflow-engine.ps1 compose-templates --core templates\core --project templates\project --output .ueef\composed\workflow
scripts\invoke-spec-workflow-engine.ps1 package-install --trust-policy .ueef\trust-policy.json --metadata package-attestation.json --store .ueef\packages --name workflow --version 1.0.0 --source templates\release
scripts\invoke-spec-workflow-engine.ps1 package-install-composition --trust-policy .ueef\trust-policy.json --metadata package-attestation.json --store .ueef\packages --name workflow --version 1.0.0 --core templates\core --project templates\project
scripts\invoke-spec-workflow-engine.ps1 package-activate --trust-policy .ueef\trust-policy.json --store .ueef\packages --name workflow --version 1.0.0 --digest <sha256>
scripts\invoke-spec-workflow-engine.ps1 package-rollback --trust-policy .ueef\trust-policy.json --store .ueef\packages --name workflow
```

## Human gates, portfolio, and control-plane status

Risk-3 work in managed production cannot be reserved without a current schema-v2 approval
ledger. Each grant binds the workflow, graph, execution, task definition digest, approver
identity and role; expiry, revocation, graph drift, execution drift, and tampering fail
closed before state mutation. `approval-status` verifies a gate and `approval-record`
appends one lock-protected, hash-chained decision.
These approval commands, high-risk `schedule`/`pending-contracts`, and approval-aware
`control-status` require a local trust policy by default. `approvalKeys` bind each identity
and key ID to at least 256 bits of separately managed key material; `approval-record` signs
the complete decision and consumers verify it. Unsigned ledgers require the explicit
`--legacy-unsigned` compatibility flag and are not production approvals.

`portfolio-status` coordinates up to 200 identity-bound feature workflows as a DAG. A child
counts as complete only after its own independent verification passes, while a failed child
blocks only descendants. `control-status` reports workflow, approval, verification, and
Codex runtime readiness without collapsing waiting, unavailable, failed, or verifying states.

## Reference updates and notices

`LICENSE.spec-kit`, `THIRD-PARTY-NOTICES.md`, and `UPSTREAM.json` preserve attribution and
provenance. `scripts/review-spec-kit-update.ps1` analyzes a separate candidate snapshot as a
manual comparison and emits a review digest without modifying the current immutable snapshot.
It is outside production runtime execution and cannot activate or import Spec Kit. Replacement
remains an explicit reviewed documentation-and-source-reference operation.

## Execution identity and state

Every reservation creates an `attemptId`, monotonic lease generation, 256-bit fencing token, heartbeat timestamp, and expiry. Contracts and receipts bind all of these fields plus workflow, execution, graph, route, and execution-spec identities. A mismatch is rejected before state mutation.

State writes use optimistic revisions, file locking, fsync, and atomic replacement. A compare-and-swap update rejects a missing target instead of recreating deleted state, and force initialization must bind the current execution identity and revision. Leases support at most three bounded renewals. Expired work is reclaimed once; a subsequent attempt receives a higher generation and a new fence. A task can start only from a live `RESERVED` lease; direct `READY` execution is rejected. Concurrent schedulers cannot reserve the same wave.

Budgeted executions keep an idempotent per-attempt `tokenLedger`. Missing terminal telemetry is charged at the task estimate, actual usage is reconciled exactly once, and an overrun fails closed before further reservation. Schema-v2 reload also enforces status-specific assignment, lease, timestamp, evidence, blocker, error, and host-handle invariants.

## Host lifecycle

Adapters advertise only supported capabilities. Every dispatch contract also carries `shellPolicy` and its exact `allowedShellCommands`; denied or non-allowlisted commands fail closed at the host contract boundary. Generic scheduling without a real worker inventory is labelled `synthetic-preview` and cannot claim capability-verified production execution. The in-process `Controller` supports capability-gated dispatch, poll, heartbeat, cancel, close, persisted handles, retry, crash recovery, and bounded no-progress return. The production facade runs complete synchronous Codex waves:

```powershell
node scripts\invoke-spec-workflow-cycle.mjs --execution-mode managed-production --spec-root . --graph task-graph.json --state execution-state.json --route route.json --cwd . --adapter codex
```

The facade initializes state when absent, schedules a wave, sends every contract through the selected bridge, combines `ueef-host-result/v2` receipts, applies them atomically, and repeats. It stops truthfully at `DONE`, `VERIFYING`, `NEEDS_REPLAN`, `FAILED`, or `BLOCKED`.

`managed-production` is Codex-only, rejects bridge and executable overrides, and reports
`productionVerified: true` only when every dispatched contract carries a matching verified
Codex App Server execution receipt. Claude and generic hosts remain available in explicit
`external` mode, and deterministic fake execution remains available only in explicit `test`
mode; neither can claim production verification. Thus compatibility is preserved without
silently downgrading the production path. Neither synchronous bridge claims cancel or
heartbeat support.

The Codex dispatcher passes the already validated route into its ephemeral host turn through a one-shot claim. The managed hook independently rechecks catalog, route, execution-spec, freshness, and selected-model identity before inheriting it. This prevents the dispatched worker from deadlocking by trying to dispatch itself again, while stale, tampered, replayed, or model-mismatched routes remain denied. Worker receipts use the protocol alias `success`; the parser normalizes it to `complete` only after the full schema-v2 identity and evidence checks, so the host Stop hook does not confuse a task receipt with a top-level project completion claim.

If a process crashes after reservation but before dispatch, `pending-contracts` rebuilds the exact contract from persisted attempt and fence identity. A host poll heartbeat also persists the lease renewal before the next cycle. External host execution is at-least-once across an unobservable mid-call process death; state application remains exactly-once through the attempt and fencing contract, so host tasks must honor their idempotent attempt identity.

For a new wave, reservation is built in a temporary state. The durable state is promoted
atomically only after the owned host bridge validates a current identity-bound receipt; a
host or receipt failure leaves durable state absent or unchanged.

A bounded SQLite transaction lock serializes readiness, staging, host dispatch, receipt
validation, and state application for each canonical state path. Concurrent controllers
therefore observe the first completed result instead of executing the same external attempt
twice. SQLite and the operating system release the transaction if a process crashes, while
normal and exceptional exits close the owning connection in `finally`.

## Verification and convergence

A schema-v2 workflow whose tasks are all done becomes `VERIFYING`, not `DONE`. Host completion evidence is a JSON object keyed exactly by every acceptance identifier in the dispatch contract; generic unbound prose cannot complete the task. Authored lifecycle preparation likewise accepts only structured REQ/AC declarations, requires plan and task mappings for both, and validates each task's evidence map. `verify` accepts an independent identity-bound report, invalidates affected write-set evidence, and records its diff digest. A pass unlocks `DONE`; a failure produces `NEEDS_REPLAN`.

Convergence rejects canonical aliases between graph and state outputs. It stages the pair and rolls back the first promotion if the second cannot be published, so a reported failure does not leave one new artifact visible by itself.

```powershell
scripts\invoke-spec-workflow-engine.ps1 verify --graph task-graph.json --state execution-state.json --report verification.json
scripts\invoke-spec-workflow-engine.ps1 replan --tasks tasks.md --graph task-graph.json --state execution-state.json --findings findings.json --route route.json --output-tasks next-tasks.md --output-graph next-graph.json --output-state next-state.json
```

Replanning appends traceable verifier gaps to the canonical Markdown, recompiles the graph, and migrates completed work. It is limited to three rounds and rejects a repeated findings fingerprint as no progress.

## Migration and rollback

`migrate` upgrades inactive v1 graph/state artifacts to compiled v2 outputs without overwriting either input. It first writes an exact rollback bundle with SHA-256 hashes. Active v1 attempts and v1 receipts are rejected because they have no safe attempt/fencing identity; release or finish them and redispatch after migration.

```powershell
scripts\invoke-spec-workflow-engine.ps1 migrate --tasks tasks.md --graph graph-v1.json --state state-v1.json --route route.json --output-graph graph-v2.json --output-state state-v2.json --backup migration-backup
```

Rollback restores the two original v1 files together from the backup. A v2 state is never rewritten in place as v1.

## Benchmarks

`benchmark-run` records a local three-mode recovery microbenchmark and `benchmark` summarizes recorded data. Schema v2 includes recovery time and evidence completeness.

```powershell
scripts\invoke-spec-workflow-engine.ps1 benchmark-run --output benchmarks\control-loop-recovery-v1.json --samples 10
scripts\invoke-spec-workflow-engine.ps1 benchmark --input benchmarks\control-loop-recovery-v1.json
```

The checked-in fixture shows 100% success, one recovered retry, and complete evidence in all modes. It also shows the durable dynamic loop has substantial local fsync/controller overhead. This is reliability/overhead evidence, not a general productivity claim.

## Verification commands

```powershell
scripts\test-spec-workflow.ps1
scripts\test-spec-workflow-engine.ps1
```
