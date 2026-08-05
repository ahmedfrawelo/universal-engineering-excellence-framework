# ADR-009: Quiet runtime validation output for nested automation

## Status

Accepted.

## Date

2026-08-05

## Context

Some UEEF automation scripts call framework validation from inside higher-level tests or runtime sync operations. These nested calls previously printed full validation summaries even when the caller intentionally discarded command output. In broad hardening tests, repeated nested syncs produced noisy logs that increased token consumption and made the relevant pass/fail result harder to inspect.

`scripts/sync-runtime.ps1` is a public runtime boundary, so changing its parameters requires an architecture decision.

## Decision

Add a `-Quiet` switch to `scripts/sync-runtime.ps1`, `scripts/write-active-state.ps1`, `scripts/validate-framework.ps1`, and `scripts/validate-fresh-review-evidence.ps1`.

When `-Quiet` is used:

- nested framework validation output is suppressed;
- active-state validation inside runtime sync is suppressed;
- fresh-review negative fixture checks do not write expected failure text;
- top-level commands keep their default human-readable output when `-Quiet` is not supplied.

Runtime hardening tests use `sync-runtime.ps1 -Quiet` because they run repeated internal sync operations and only need the final hardening verdict.

## Consequences

- Normal manual validation remains readable.
- Nested validation no longer floods task transcripts with repeated PASS/FAIL summaries.
- The public sync boundary changes intentionally and is covered by the architecture gate.
