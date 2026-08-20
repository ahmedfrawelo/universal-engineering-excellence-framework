# UEEF Independent-Review Deadlock Repair — 2026-08-16

This handoff records a focused, uncommitted repair to the managed Codex enforcement path. It supplements the broader orchestration handoff and supersedes only its statement that an independent-review contract must contain an exact set of JSON keys.

## 1. User-visible incident

A T4 task completed route recording, then attempted to start the mandatory independent reviewer. The managed hook rejected the available `UEEF_INDEPENDENT_REVIEW` contract variants. Because safe lead reads were restricted to T0/T1, the same T4 turn could not continue with repository inspection or diagnose the rejected dispatch. The task stopped before reading or modifying the target project.

The failure was in UEEF orchestration. It was not caused by the ABRD project or its files.

## 2. Root cause

Two enforcement decisions combined into a deadlock:

1. `independentVerifierContractValid` required exact equality between the contract's JSON keys and five canonical keys. Harmless host-added serialization metadata, or a host wrapping the same JSON object in a single `json` code fence, caused rejection even when all security-bearing fields were valid.
2. `isEconomicalLeadRead` returned false for every T2–T4 route. After a T4 dispatch problem, isolated safe read-only recovery commands were therefore denied while the turn was waiting for dispatch evidence.

The strict contract validation and the read restriction were each defensible in isolation, but together they created a state from which the task could not recover.

## 3. Implemented repair

Source changes are in `scripts/codex-hooks/ueef-codex-hook.mjs`:

- contract validation still requires the exact security-bearing values:
  - task name `independent_review`;
  - `schemaVersion: 1`;
  - `kind: UEEF_INDEPENDENT_REVIEW`;
  - `readOnly: true`;
  - objective `CURRENT_WORKTREE_DIFF`;
  - one or more unique checks from the bounded allowlist;
- additive host metadata no longer invalidates an otherwise valid contract;
- a single JSON object wrapped only in a `json` code fence is accepted;
- free-form prose surrounding the contract remains rejected;
- isolated allowlisted read-only recovery commands are available at every tier, including T4.

The installed managed runtime was synchronized from the current source after the focused tests passed.

## 4. Security boundaries preserved

This repair does not grant implementation authority to the independent reviewer. It does not relax:

- `readOnly: true`;
- the fixed reviewer task name and objective;
- the bounded review-check allowlist;
- `fork_turns: none` fresh-context isolation;
- mutation, destructive-command, protected-path, browser, spec, completion, or release gates;
- the requirement for T4 fresh-review evidence before a T4 completion claim.

Compound shell commands remain subject to the shell-control guard. For example, two read commands joined by a semicolon may be denied while each isolated read is permitted. This is intentional and is separate from the repaired T4 deadlock.

## 5. Regression coverage

`scripts/test-managed-enforcement.ps1` now proves that:

- a canonical bounded independent-review contract remains accepted;
- harmless additive host metadata does not reject that contract;
- a canonical contract inside a single `json` fence is accepted;
- a routed T4 turn can still run an isolated safe read before model dispatch completes;
- contradictory, mutating, wrong-name, wrong-objective, inherited-history, and unauthorized worker requests remain denied.

Focused verification on 2026-08-16:

```text
Managed enforcement tests passed
```

After runtime synchronization, live status reported:

```text
Managed enforcement: PASS
Managed enforcement effective: PASS
Runtime drift: PASS
Runtime drift mode: CACHED_CONTENT_VERIFIED
Runtime source revision: PASS
Overall: ACTIVE
```

## 6. Delivery state

- Source repair: present in the current dirty working tree.
- Regression tests: present and passing locally.
- Installed Codex runtime: synchronized and ACTIVE at the recorded verification time.
- Target user projects, including ABRD: not modified by this repair.
- Commit: not created.
- Push: not performed.
- Pull-request update: not performed.
- Merge: not performed.
- Release or tag: not created.

Current command output always overrides this snapshot. Do not describe this repair as committed, merged, or released until those actions actually occur.

## 7. Files directly involved

- `scripts/codex-hooks/ueef-codex-hook.mjs`
- `scripts/test-managed-enforcement.ps1`
- `docs/handoffs/2026-08-16-independent-review-deadlock-repair.md`
- generated installed copies under the Codex-owned UEEF runtime root

## 8. Receiving-task check

Before relying on this repair in a later task, run isolated commands rather than a chained command:

```powershell
Get-Content -Raw 'D:\shared folder\codex-home\ueef\codex\UEEF-LOADER.md'
& 'D:\shared folder\codex-home\ueef\codex\scripts\ueef-status.ps1'
& .\scripts\test-managed-enforcement.ps1
git status --short
```

Require the live runtime and focused test to pass. Preserve the distinction between source changes, installed runtime state, and Git delivery state.

## 9. Follow-up reliability repair — 2026-08-17

A cross-project closeout report exposed additional recurring failures: missing route/turn state, silent route discovery, App Server requirements timeouts, `EPERM` on the discovery lock, `REFRESH_REQUIRED`, protected-state coupling in evidence authoring, and manually mismatched completion-audit hashes.

The focused follow-up changed the canonical owners as follows:

- `scripts/codex-app-server-client-lib.mjs` now places the default discovery lock under the OS temporary directory, namespaced by user and Codex installation. Read-only App Server turns no longer need write access to the managed runtime merely to inspect requirements or models. An explicit lock-root override remains authoritative.
- `scripts/codex-hooks/record-ueef-route.mjs` reduced the bounded live-catalog discovery envelope from the previous multi-minute worst case to 55 seconds and writes progress messages to stderr before and after discovery. It also supports `--print-binding`, which emits only the work-unit identity, tier, route digest, and execution-spec digest; evidence authors no longer need to embed a protected state-file path.
- `scripts/validate-completion-audit.ps1` supports the explicit `-RefreshSourceHash` switch. It recomputes SHA-256 from the exact UTF-8 `sourceReview.sourceText`, rejects linked audit files, writes through a temporary file, and then performs the normal strict validation. It does not repair review-unit bounds, quotes, evidence, or completion claims.

Focused regression evidence on 2026-08-17:

```text
App Server discovery lock tests passed
Completion audit tests passed
Managed enforcement tests passed
```

The synchronized installed runtime then reported:

```text
Managed enforcement effective: PASS
Runtime drift: PASS
Runtime drift mode: CACHED_CONTENT_VERIFIED
Runtime source revision: PASS
Overall: ACTIVE
```

A direct installed requirements probe with `--timeout-ms 5000 --discovery-lock-wait-ms 2000` completed successfully in about 1.5 seconds and returned the managed hook requirements. This specifically verifies the repaired discovery-lock path in the writable parent environment. The route's isolated App Server work turn also completed successfully, but took about 132 seconds to return its diagnostic response; that duration is work-turn latency, not live-catalog route-recording latency, and is not being reported as a 5-second route result.

The follow-up remains uncommitted and unreleased. No BOQ, Hierarchy, Toast, Engineering Units, or other user-project source was modified.
