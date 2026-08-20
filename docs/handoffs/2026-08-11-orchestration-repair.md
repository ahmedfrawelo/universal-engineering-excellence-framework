# UEEF Orchestration Repair Handoff — 2026-08-11

This is the authoritative working handoff for the current unmerged orchestration repair. It is written for a new Codex task that must continue from current evidence rather than conversational memory.

## 1. Delivery identity

- Source repository: `E:\MY DATA\div\universal-engineering-excellence-framework`
- Upstream: `https://github.com/ahmedfrawelo/universal-engineering-excellence-framework.git`
- Version metadata: `2.27.0`
- Working branch: `codex/fix-ueef-orchestration`
- Current head: resolve with `git rev-parse HEAD`; at handoff creation it was `e02331d873183606fb9eaeb15db8da863c0e4688`
- Divergence at handoff creation: `origin/main...HEAD = 0 4`
- Pull request: <https://github.com/ahmedfrawelo/universal-engineering-excellence-framework/pull/2>
- Pull request state: draft, merge state `CLEAN`
- Installed runtime: `D:\shared folder\codex-home\ueef\codex`
- Runtime version: `2.27.0`
- Runtime status at handoff creation: `Overall: ACTIVE`, drift `PASS`, source revision `PASS`

Live Git, GitHub, and runtime output always override copied values in this document.

## 2. What UEEF is

UEEF is an installable engineering operating system for AI coding agents, not a business application. It owns:

- proportional T0–T4 work classification;
- model, host-reasoning, and fallback routing;
- bounded delegation and independent review;
- managed hook enforcement;
- specification-driven workflow compilation and execution;
- repository intelligence;
- evidence, approval, completion, and convergence controls;
- browser safety contracts;
- transactional installation, runtime synchronization, drift detection, and recovery;
- cross-platform validation and release governance.

The source checkout is editable authority. The installed Codex runtime is a generated self-contained copy. Never edit the runtime as the source of truth.

## 3. Required first reads for a new task

Read in this order:

1. `D:\shared folder\codex-home\ueef\codex\UEEF-LOADER.md`
2. `docs/PROJECT-HANDOFF.md`
3. this file
4. `docs/handoffs/2026-08-09-dynamic-runtime-repair.md`
5. only the canonical modules selected by `framework/01-core/01-master-loader.md`

Always-loaded modules remain exactly:

```text
Loaded: boot-loader, core-system
```

Do not load the whole framework unless the requested work is an audit, update, installation, validation, or rebuild.

## 4. Current branch change set

Compared with `origin/main`, the branch currently contains 33 changed files, approximately 956 insertions and 84 deletions. The four commits are:

```text
e02331d align Unix skeleton contract with canonical core
4f9509c align Unix browser contract with compact loader
8bec287 fix CI portability regressions
ee3cf46 fix UEEF orchestration and runtime recovery
```

Main ownership surfaces changed:

- `config/model-routing-policy.json`
- `scripts/select-agent-route.ps1`
- `scripts/select-agent-route.sh`
- `scripts/resolve-model-route.mjs`
- `scripts/codex-app-server-models.mjs`
- `scripts/codex-app-server-dispatch.mjs`
- `scripts/record-model-route-result.mjs`
- `scripts/codex-hooks/record-ueef-route.mjs`
- `scripts/codex-hooks/ueef-codex-hook.mjs`
- `scripts/codex-hooks/ueef-hook-common.mjs`
- `scripts/sync-runtime.ps1`
- `engines/spec-workflow/ueef/ueef_spec_workflow/compiler.py`
- `engines/spec-workflow/ueef/ueef_spec_workflow/safe_workflow.py`
- associated routing, enforcement, compiler, workflow, runtime, Unix, and Windows regressions.

Use `git diff --name-status origin/main...HEAD` and `git diff origin/main...HEAD -- <path>` for exact current content.

## 5. Problems repaired in this branch

### 5.1 Model-route discovery and dispatch deadlocks

The route resolver previously nested timeout budgets poorly and could be killed by its outer process before producing a structured failure. The repair:

- validates catalog timeout input;
- gives catalog discovery and the resolver separate bounded budgets;
- carries structured discovery errors;
- preserves fail-closed behavior when `codex` is absent;
- tests both owned timeouts and CI runners where `codex` is not installed.

### 5.2 Cross-agent route overwrite

Workers inherit session/turn identifiers, so state keyed only by session/turn allowed a child to replace the lead route. The repair:

- binds turn state to `CODEX_THREAD_ID` ownership;
- rejects cross-thread state replacement;
- rechecks ownership under the state lock;
- binds the prompt hash to prevent a time-of-check/time-of-use overwrite;
- adds `scripts/test-cross-agent-route-ownership.mjs`.

### 5.3 Untrusted inherited route authority

Prompt-embedded route paths are no longer authority by themselves. Inheritance requires exact equality with dispatcher-provided trusted environment paths, validates canonical route identity/digests, and consumes a one-shot claim. Missing environment, mismatch, tampering, staleness, model mismatch, and replay fail closed.

### 5.4 Visible Mode / Spec / Team decision

Routing now emits and digest-binds a canonical decision:

- `mode`
- `spec`
- `specReason`
- `team`
- `teamReason`
- delegation benefit, authorization, source, and scope.

Routes missing the canonical decision are rejected except explicit test-only fixtures. The managed hook requires the visible execution-policy line before mutation.

### 5.5 Delegation authority tightening

Delegation authorization is a tuple: the authorization flag and source must both exist. Supported sources are bounded. `PLATFORM_POLICY` grants only an independent verifier; it does not grant implementation workers.

The platform verifier channel is closed rather than free-form:

- task name exactly `independent_review`;
- `fork_turns` exactly `none` for fresh-context isolation;
- exact-key JSON message;
- fixed kind `UEEF_INDEPENDENT_REVIEW`;
- fixed objective `CURRENT_WORKTREE_DIFF`;
- `readOnly: true`;
- bounded allowlisted checks.

This closes mixed read-only/implementation prompts, mutation verbs in other languages, malicious task names, and full-history instruction inheritance.

### 5.6 Spec validation and authoring invalidation

T3/T4 or durable-spec-required work must validate the route-bound Ready spec before substantive mutation. Spec authoring inside `.ueef/specs/**` is allowed only within bounded Add/Update operations. Changing the spec invalidates the previous validation, preventing stale Ready evidence from authorizing later code changes.

### 5.7 Safe workflow semantics

`safe_workflow.py` now provides a bounded UEEF-native semantic subset:

- dynamic loops may use a supplied boolean condition and re-evaluate per iteration;
- while false executes zero times; do-while false executes once;
- loops remain bounded;
- executable command/shell/prompt fields fail closed;
- workflow, overlay, title, and expansion sizes are bounded.

Human gates from the reference format are rejected unless represented by the trusted UEEF approval path. They are not silently converted into ordinary tasks.

### 5.8 Compiler route authority

The Spec workflow compiler no longer trusts shape-valid route JSON. It recomputes:

- canonical `executionSpec.digest`;
- canonical `routeDigest` from the exact recorder identity field order and JSON encoding contract.

Route or execution-spec tampering is rejected. The production `assert` was replaced by explicit validation so Bandit passes.

### 5.9 Windows runtime synchronization corruption window

A live synchronization exposed a real Windows failure: recursive `Move-Item` partially moved a runtime when an executable was locked, then rollback encountered a nested partial tree. The repair:

- uses same-volume `[IO.Directory]::Move` atomic renames for runtime/staging/rollback swaps;
- separates pre-commit compensation from post-commit cleanup;
- sets an explicit transaction-wide committed boundary;
- prevents post-commit warnings/output failures from rolling back AGENTS, state, hooks, and requirements into a mixed generation;
- makes obsolete rollback cleanup best effort;
- tests locked rename, pre-commit failure, rollback-cleanup failure, and `WarningPreference=Stop` after commit.

### 5.10 Cross-platform CI drift

Unix contract tests still expected verbose rules inside the newly compact loader. They now verify compact invariants in the loader and detailed rules in canonical modules, matching the Windows contracts. The timeout regression also accepts a clean fail-closed `spawn codex ENOENT` on minimal CI runners.

## 6. Verification evidence on the exact branch

GitHub Actions run `31487260470` passed on the current handoff head:

- Repository engine tests: `SUCCESS`
- Spec workflow engine tests: `SUCCESS`
- Unix validation: `SUCCESS`
- Windows validation: `SUCCESS` (including installer integration and full runtime hardening; about 9 minutes 38 seconds)

Local evidence included:

- `scripts/test-spec-workflow-engine.ps1`: 154 tests PASS;
- Bandit PASS;
- Ruff PASS;
- Pyright: 0 errors, 0 warnings;
- compiler focused tests PASS;
- route timeout recovery PASS;
- agent-route PowerShell and shell parity PASS;
- managed enforcement PASS;
- host-route inheritance PASS;
- App Server dispatch PASS;
- cross-agent ownership PASS;
- full Unix validation PASS;
- runtime synchronization PASS;
- installed runtime status ACTIVE with drift and source revision PASS.

The local full Windows validation wrapper exceeded the command-tool timeout during one concurrent run and one long sequential run. This is not being used as proof. The authoritative clean GitHub Windows job completed successfully on the exact commit and exercised framework validation, installer integration, and full runtime hardening.

## 7. Current GitHub and delivery state

The branch is pushed and matches its upstream branch (`0 0` divergence at handoff creation). Pull request #2 is a draft and is not merged. No new tag or GitHub Release was created for these repairs. Therefore distinguish these facts:

- implementation: complete on the branch;
- push: complete;
- PR: open, draft, clean, green;
- merge to `main`: not done;
- version bump: not done;
- release tag/release publication: not done;
- runtime sync from the branch: done and ACTIVE.

Do not say the changes are released or on `main` until those external actions actually occur.

## 8. Deliberate boundaries — especially Spec Kit parity

Do not claim format-wide or ecosystem-wide Spec Kit parity.

What is true:

- `engines/spec-workflow/upstream/spec-kit/` is an immutable reference/provenance snapshot only;
- production UEEF code does not import or execute the snapshot;
- UEEF implements selected production semantics independently, with stronger identity, fencing, approval, package trust, atomic state, and recovery controls;
- executable hooks, arbitrary commands/prompts, unrestricted expressions, and untrusted plugins fail closed;
- bounded fan-out/fan-in, loops, dependencies, catalogs, packages, approvals, portfolios, and composition are UEEF-owned.

What is intentionally not claimed:

- every Spec Kit CLI command or file format;
- its complete extension/preset/bundle ecosystem-management breadth;
- all editor or third-party integrations;
- remote marketplace fetch/install parity;
- unrestricted executable workflow semantics.

Installed execution adapters are intentionally bounded to UEEF-supported hosts such as Codex, Claude, and generic contracts rather than every upstream editor integration.

## 9. Known operational limitations and residuals

1. **External side effects:** state application is exactly-once under UEEF attempt/fence identity. If a controller dies during an unobservable synchronous external host call, the external side effect remains at-least-once. Workers must use `attemptId` as the idempotency identity.
2. **Provider capacity:** UEEF cannot make an unavailable model available, rotate ChatGPT accounts/cookies, or bypass provider capacity.
3. **Browser proof:** source/CI tests do not prove user-visible browser behavior. Browser work still requires the explicit existing-Chrome task-tab policy and visual evidence.
4. **Draft delivery:** PR #2 is deliberately draft and unmerged.
5. **Rollback cleanup debris:** runtime sync committed successfully but Windows could not fully delete `D:\shared folder\codex-home\ueef\.r0feeca63`. Most of it was deleted; six directory/file entries remained because two `ueef-repository-intelligence status` process trees for `E:\MY DATA\div\PERSONAL` held the moved executable images open. Do not kill unrelated processes merely to clean it. After those processes exit, verify the exact path and remove only that rollback directory. It does not affect the ACTIVE runtime.
6. **Task-local artifacts:** `.ueef` is ignored. Specs, evidence, routes, and completion artifacts there are not durable across clones unless copied into tracked documentation.

## 10. Project map

| Path | Purpose |
|---|---|
| `UEEF-LOADER.md` | Compact source loader and invariant pointers. |
| `framework/01-core` | Boot, core, lifecycle, scope, continuation, and FREE-MODE owners. |
| `framework/03-runtime` | Runtime sequence and evidence fields. |
| `framework/12-delivery-quality` | Gates, scorecards, checklists, and completion controls. |
| `framework/18-runtime-operations` | Bootstrap, browser safety, workspace hygiene, assurance. |
| `framework/19-agent-workflow` | Model orchestration, skill protocol, spec-driven development. |
| `framework/20-repository-evolution` | Modernization, repository intelligence, performance forensics. |
| `engines/repository-intelligence` | Repository graph and intelligence engine. |
| `engines/spec-workflow` | UEEF-owned executable specification workflow engine. |
| `scripts/codex-hooks` | Managed Codex enforcement and route-recording implementation. |
| `scripts` | Routing, dispatch, install, sync, validation, evidence, tests, recovery. |
| `config` | Routing, enforcement, skills, capabilities, adapters, release policy. |
| `docs` | Architecture, releases, attribution, operations, and handoffs. |
| `.ueef` | Ignored task-local generated state and evidence. |

Stable numbered framework packs must not be renamed casually. A structural move requires coordinated loader, index, manifest, validator, runtime-sync, and consumer updates.

## 11. Safe intake commands for the next task

Run read-only intake first:

```powershell
Set-Location 'E:\MY DATA\div\universal-engineering-excellence-framework'
Get-Content -Raw 'D:\shared folder\codex-home\ueef\codex\UEEF-LOADER.md'
& 'D:\shared folder\codex-home\ueef\codex\scripts\ueef-status.ps1'
git status --short
git branch --show-current
git log --oneline -8
git rev-list --left-right --count origin/main...HEAD
git diff --stat origin/main...HEAD
gh pr view 2 --json url,isDraft,mergeStateStatus,headRefName,headRefOid,statusCheckRollup
```

Expected at this snapshot: clean worktree, branch `codex/fix-ueef-orchestration`, four commits ahead of main, PR #2 clean with four successful checks, runtime ACTIVE.

Do not reset, clean, merge, mark ready, release, or delete rollback debris without the user's current instruction and fresh evidence.

## 12. Validation cookbook

Focused orchestration and engine checks:

```powershell
& .\scripts\test-agent-route.ps1
& .\scripts\test-managed-enforcement.ps1
node .\scripts\test-host-route-inheritance.mjs
node .\scripts\test-codex-app-server-dispatch.mjs
node .\scripts\test-routing-timeout-recovery.mjs
node .\scripts\test-cross-agent-route-ownership.mjs
& .\scripts\test-spec-workflow-engine.ps1
```

Spec workflow quality checks:

```powershell
Set-Location .\engines\spec-workflow
uv run --frozen bandit -q -r ueef/ueef_spec_workflow
uv run --frozen ruff check ueef tests
uv run --frozen pyright ueef tests
```

Full framework and installed runtime:

```powershell
Set-Location 'E:\MY DATA\div\universal-engineering-excellence-framework'
& .\scripts\validate-framework.ps1
& .\scripts\test-runtime-hardening.ps1
& .\scripts\sync-runtime.ps1 -SourcePath . -CodexHome 'D:\shared folder\codex-home' -Agent codex -Quiet
& 'D:\shared folder\codex-home\ueef\codex\scripts\ueef-status.ps1'
```

Require ACTIVE, drift PASS, and source revision PASS before claiming activation.

## 13. Recommended next-task behavior

The new task should not redo the completed repair. It should:

1. verify intake evidence;
2. ask the user what new work they want to perform with the project;
3. map that new request to the existing plan and owners;
4. preserve the clean branch and green PR unless the new request requires changes;
5. keep PR/merge/release/runtime facts separate;
6. avoid saying “100% equivalent to Spec Kit”; use the precise boundary in section 8;
7. append a new dated handoff if it materially changes the branch, runtime, PR, or known residuals.

## 14. Copy-ready intake instruction for the new Codex task

```text
You are receiving the UEEF project in its current working repository. Start with intake and understanding; do not modify, reset, clean, merge, release, or delete anything until you have inspected current state and received the user's new requested work.

Repository: E:\MY DATA\div\universal-engineering-excellence-framework
Runtime: D:\shared folder\codex-home\ueef\codex
Current branch expected: codex/fix-ueef-orchestration
Current PR: https://github.com/ahmedfrawelo/universal-engineering-excellence-framework/pull/2

Read fully:
- D:\shared folder\codex-home\ueef\codex\UEEF-LOADER.md
- docs\PROJECT-HANDOFF.md
- docs\handoffs\2026-08-11-orchestration-repair.md
- docs\handoffs\2026-08-09-dynamic-runtime-repair.md

Then run read-only intake:
- runtime ueef-status.ps1
- git status --short
- git branch --show-current
- git log --oneline -8
- git rev-list --left-right --count origin/main...HEAD
- git diff --stat origin/main...HEAD
- gh pr view 2 with statusCheckRollup

Treat current command output as authoritative. Preserve the exact distinction between branch implementation, draft PR, merge, release, and installed runtime. Do not claim full Spec Kit CLI/ecosystem parity; UEEF is an independent, safer, deliberately bounded semantic implementation. After summarizing what you verified, tell the user you have received the project and ask for the new work they want to do together.
```

## 15. Handoff acceptance

This handoff is accepted only after the receiving task independently confirms Git, PR, and runtime state. It must report any divergence rather than silently normalizing it.
