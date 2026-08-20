# UEEF Issues and Fixes Closeout - 2026-08-17

## Purpose

This note records the problems observed during recent Codex/UEEF work, what was fixed in UEEF, what was only worked around, and what still needs project-specific follow-up.

It is not a release note and it does not claim that every downstream project build/test is green. The current live UEEF runtime status remains the authority for whether managed UEEF is active.

## Current UEEF Runtime Status

Latest checked state during this closeout:

- Version: `2.27.0`
- Installed: `YES`
- Mode: `managed-runtime`
- Managed enforcement: `PASS`
- Managed enforcement effective: `PASS`
- Runtime drift: `PASS`
- Runtime drift mode: `CACHED_CONTENT_VERIFIED`
- Runtime source revision: `PASS`
- Overall: `ACTIVE`

This means the UEEF installation is currently heard by Codex and the managed runtime is active.

## Problems That Were Fixed In UEEF

### 1. Dynamic route and current turn state failures

Observed symptoms:

- `UEEF dynamic model route is missing`
- `No current UEEF turn state exists`
- tools rejected after route registration failed
- route recorder hanging or ending without useful final output
- independent-review route rejected before the agent could read instructions

What was fixed:

- Route recording was hardened so catalog discovery is bounded and reports progress instead of appearing silent.
- A protected-path-free route binding mode was added for cases where a task needs to prove routing metadata without reading managed internal state files.
- Safe isolated reads were allowed at all tiers where the route contract permits them.
- Independent-review contract validation was relaxed for harmless additive metadata and a single fenced JSON object while keeping security-bearing fields strict.

Verification recorded:

- `test-routing-timeout-recovery.mjs` passed.
- `test-managed-enforcement.ps1` passed.
- direct route recording completed successfully for current documentation work.

### 2. App Server discovery timeout and lock permission failure

Observed symptoms:

- `Codex App Server requirements discovery failed: Timed out after 5000 ms`
- long waits before any useful output
- App Server child process could hit `EPERM` while creating a catalog lock under the managed UEEF runtime path

What was fixed:

- Discovery lock location now defaults to the OS temp directory, namespaced by user and runtime path digest.
- Explicit `UEEF_APP_SERVER_DISCOVERY_LOCK_ROOT` still works when needed.
- This avoids requiring write access inside the managed UEEF runtime during read-only App Server turns.
- Catalog discovery budgets were reduced and bounded.

Verification recorded:

- `test-app-server-discovery-lock.mjs` passed.
- installed requirements probe with short timeout completed quickly after the fix.

### 3. Runtime drift / inactive status caused by stale or slow drift verification

Observed symptoms:

- `Overall: INACTIVE`
- `Runtime drift: FAIL`
- `Runtime drift mode: REFRESH_REQUIRED`
- status checks taking too long when broad hashing hit slow filesystem paths
- cache could previously be unsafe if metadata matched while content changed

What was fixed:

- Runtime hashing was moved to a bounded parallel helper.
- Runtime metadata/cache validation was hardened so same-size edits with restored timestamps are detected.
- Status cache acceptance now uses stronger checks and fails closed on stale source revision.
- Sync/cache behavior verifies mismatch conditions before trusting cached state.

Verification recorded:

- `test-runtime-metadata-signature.ps1` passed.
- `test-runtime-hardening.ps1` passed in focused runs.
- final live UEEF status returned `Overall: ACTIVE` and `runtimeDrift PASS`.

### 4. Completion audit hash mismatch

Observed symptoms:

- completion audit failed because `sourceReview.sourceText` hash no longer matched the stored hash.
- rerunning the validator alone did not repair stale source hash evidence.

What was fixed:

- `validate-completion-audit.ps1` gained explicit `-RefreshSourceHash`.
- The refresh path recomputes the SHA-256 from the exact current `sourceReview.sourceText`, writes atomically through a temporary file, and then reruns normal validation.
- It rejects unsafe/reparse paths before writing.

Verification recorded:

- `test-completion-audit.ps1` passed.
- task-local completion audit validation passed for the repair task.

### 5. Protected-path evidence problem

Observed symptoms:

- evidence attempts failed when they pointed directly at managed runtime internal state files.
- this could block documentation/proof even when the task itself did not need secret or protected runtime state.

What was fixed:

- route binding output can now provide safe route proof without exposing protected internal state.
- evidence can reference task-owned artifacts instead of managed runtime internals.

Verification recorded:

- protected-path-free route binding was covered by managed-enforcement tests.

## Problems That Were Worked Around, Not Fully Solved

### 1. FREE-MODE usage

Observed behavior:

- FREE-MODE was used in some chats after direct user authorization because UEEF routing/runtime failures were blocking normal progress.

Current policy:

- FREE-MODE can reduce repository ceremony when explicitly authorized.
- It does not override safety, truthfulness, scope, destructive-action rules, browser rules, or user authorization.
- It must not be used to claim tests passed when they did not finish.

Current state:

- Because UEEF is now `ACTIVE`, normal UEEF routing should be used again unless a future live failure forces a documented fallback.

### 2. Long Codex turn latency

Observed behavior:

- one direct App Server work turn took roughly two minutes.

Important distinction:

- That was end-to-end task response latency, not proof that route/catalog discovery itself still takes two minutes.
- The route/catalog path was reduced and bounded; slow host/model scheduling can still make a Codex turn feel slow.

## Problems Not Proven To Be UEEF Defects

These need separate reproduction inside the owning project repositories before changing project code.

### 1. Git and filesystem slowness

Observed symptoms:

- slow or hanging `git status`
- slow or hanging `git diff --check`
- some working directories not showing `.git` consistently
- `I/O device error` while reading parts of a tree
- broad reads over `docs` or large files taking too long

Current assessment:

- This looks like a Windows/filesystem/drive or repository-size condition, not a confirmed UEEF logic bug.
- The safe response is to narrow scans, use explicit paths, and report incomplete checks honestly.

Needed follow-up:

- reproduce in the affected repository;
- capture exact command, cwd, elapsed time, and error;
- check drive health/path stability before treating it as a code failure.

### 2. Vitest hangs

Observed symptoms:

- Vitest started but did not return conclusive `PASS` or `FAIL`;
- Windows worker pool was slow or stuck;
- `--runInBand` was not supported by the installed Vitest version;
- focused Toast tests did not finish within the wait window.

Current assessment:

- Not proven to be caused by UEEF.
- The correct closeout is to say the test was attempted but inconclusive.

Needed follow-up:

- inspect the specific project `vitest.config`;
- use supported options for that Vitest version;
- reduce worker count using supported pool configuration;
- rerun the focused spec and capture a real result.

### 3. Angular CLI build failure

Observed symptom:

- `node:fs UNKNOWN read` during Angular CLI loading.

Current assessment:

- This happened before a normal Angular assertion/build result.
- Treat it as runner/filesystem/environment failure until reproduced.

Needed follow-up:

- rerun in the owning Angular repo;
- record Node version, Angular CLI version, cwd, exact command, and whether the same error repeats;
- only then decide whether project code or environment needs a fix.

### 4. Toast implementation status

Observed facts:

- the Toast layout fix exists in `getBlobLayout(...)`;
- the change is limited to blob width calculation relative to viewport;
- focused test execution did not produce a conclusive current result.

Current assessment:

- Source review supports that the intended fix exists.
- Test proof remains incomplete until a focused run returns a real `PASS`.

Needed follow-up:

- run the owning Toast spec in the actual project;
- if Vitest still hangs, fix the runner configuration first or document the runner blocker separately.

### 5. Engineering Units evidence/audit issues

Observed symptoms:

- first evidence attempt was rejected because it pointed directly at protected managed runtime state;
- completion audit failed once due to sourceText hash mismatch.

Current assessment:

- The UEEF-side mechanisms for safe route proof and explicit hash refresh were fixed.
- Any remaining Engineering Units business logic or test gaps must be verified inside that project.

## What Is Solved Now

- UEEF managed runtime is currently active.
- Runtime drift is currently passing.
- Source revision check is currently passing.
- Managed enforcement is currently effective.
- Route recording no longer needs protected internal-state reads for safe route proof.
- App Server discovery no longer depends on writing lock files inside the managed runtime path.
- Completion audit stale source hash has an explicit repair command.
- Evidence can be recorded without direct protected runtime-state references.

## What Is Not Solved Yet

- Downstream project builds are not globally proven green.
- Vitest hangs in specific projects are not fixed globally.
- Angular CLI `node:fs UNKNOWN read` is not fixed globally.
- Git/filesystem slowness and I/O errors are not fixed globally.
- Toast behavior is not browser-verified here.
- BOQ, Hierarchy, ABRD, FRDW, Work Plus, or any other business project was not modified by this closeout.

## Practical Operating Rule Going Forward

For future work:

1. If the issue is UEEF route/status/evidence/audit, start in this repository and verify with UEEF tests/status.
2. If the issue is a project build/test/UI bug, start in that project's repository and treat UEEF only as the workflow guard.
3. If a runner hangs or filesystem read fails before assertions, document it as an environment/runner blocker unless a repeatable code-level cause is found.
4. Do not claim a build, browser check, or test passed unless the current command actually returned a passing result.
