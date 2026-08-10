# UEEF Dynamic Runtime Repair Handoff - 2026-08-09

## Scope

This change repairs the Spec workflow dynamic execution path and the nested Codex model-route deadlock. It does not publish a release, commit, push, or claim runtime activation without a successful source-to-runtime synchronization and installed status check.

## Delivered source behavior

- `tasks.md` is canonical and compiles deterministically to a route-bound schema-v2 graph; manual graph or source drift is rejected.
- Route worker caps cannot be widened by authored workflow configuration.
- Every execution has a UUID; every attempt has a monotonic generation, UUID, 256-bit fence, bounded lease, heartbeat, and expiry.
- Contracts and receipts bind workflow, execution, graph, route, execution spec, task, worker, attempt, generation, and fence identities.
- Stale or mismatched receipts are rejected before state mutation; schema-v1 receipts cannot enter the fence-safe path.
- Persisted reservations can rebuild their exact contracts after restart. Host heartbeats persist lease renewal, and expired attempts reclaim with a new generation and fence.
- The Codex dispatcher passes a fresh account-verified route to the ephemeral worker as a one-shot claim. The worker hook revalidates all route digests, freshness, execution spec, and selected model before inheriting it, eliminating recursive self-dispatch.
- Task receipts use `success` at the host boundary and normalize internally only after strict parsing. Arbitrary non-JSON host text is never wrapped as success.
- Schema-v2 completion requires an independent verifier; write-set changes invalidate evidence, and canonical replanning is bounded to three non-repeating rounds.
- Inactive v1 graph/state pairs migrate non-destructively with exact hash-backed rollback. Active unfenced v1 attempts are rejected.
- Fault injection and a checked-in local recovery benchmark cover duplicate, stale, expiry, cancellation, partial failure, restart, and evidence completeness behavior.
- The Frawelo v2.26.2 review was revalidated finding by finding: live lease admission, direct-READY denial, token-ledger enforcement, deletion-safe CAS, persisted-state invariants, worker capacity, shell authority, structured traceability, team targets, and transactional convergence now have current regressions.
- Completion receipts bind evidence to every acceptance identifier; generic prose cannot satisfy a terminal host result.
- Deliberate reference boundaries remain explicit: the installed Spec Kit snapshot is review/provenance material only, executable hooks/commands/prompts and unrestricted expressions are rejected, and UEEF does not claim format-wide CLI or editor-integration parity.

## Verification entrypoints

```powershell
& .\scripts\test-spec-workflow-engine.ps1
& .\scripts\test-spec-workflow.ps1
& .\scripts\test-managed-enforcement.ps1
& .\scripts\test-codex-app-server-dispatch.mjs
& .\scripts\validate-framework.ps1
```

Python quality checks run from `engines/spec-workflow` and intentionally exclude the immutable `upstream/spec-kit` snapshot:

```powershell
uv run --frozen --group dev ruff check ueef tests
uv run --frozen --group dev pyright ueef
```

## Runtime activation gate

The source hook fix is not active merely because source tests pass. Apply it only through the documented transactional sync:

```powershell
& .\scripts\sync-runtime.ps1 -CodexHome 'D:\shared folder\codex-home' -Agent codex -BackupRoot 'D:\shared folder\codex-home-backups'
& 'D:\shared folder\codex-home\ueef\codex\scripts\ueef-status.ps1'
```

After sync, require `Overall: ACTIVE`, `Runtime drift: PASS`, and `Runtime source revision: PASS`, then run `scripts/run-spec-workflow-real-host-smoke.mjs` with a freshly resolved route. The smoke must return a schema-version-2 `PASS` receipt with real acceptance evidence; label-only or unstructured text is a failure.

## Operational boundary

State application is exactly-once under the attempt/fencing contract. An external synchronous host call remains at-least-once if the controller process dies during the unobservable call itself, so workers must treat `attemptId` as their idempotency identity. No source code can make an external side effect exactly-once without a host idempotency API.
