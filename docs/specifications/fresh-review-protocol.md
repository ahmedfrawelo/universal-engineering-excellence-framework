# Fresh Review Protocol Specification

## Outcome

For consequential UEEF delivery, a reviewer who did not produce the implementation can inspect the bounded final change set and verification evidence before completion. The result must be machine-validatable, linked to the reviewed diff identity, and invalidated by any later change.

## Requirements

1. The task router exposes a proportional review mode without hard-coding a model name.
2. T3 routes recommend fresh review for consequential architecture and broad changes, while allowing a documented direct-review fallback when no eligible review lane exists.
3. T4 routes require fresh-context review evidence when an eligible lane is available. The lead triggers the selected fresh-review lane automatically during completion; the user is not asked to issue a separate "run reviewer" prompt. No fallback may be represented as independent review.
4. Evidence records the reviewer identity, role, capability, observable reasoning, sandbox and permission context, verdict, reason, reviewed paths, final diff hash, and verification commands/results.
5. `ship` is the only verdict that can support completion. `fix-first`, `rethink`, changed post-review diffs, reused implementation identity, and invalid hashes must fail validation.
6. Managed enforcement blocks a T4 completion claim unless fresh-review validation passed in that turn.
7. The capability has PowerShell and Unix route parity, focused tests, framework validation coverage, documentation, and third-party attribution.

## Non-Goals

- Do not force a named model, vendor, or all tasks through a subagent.
- Do not install an external plugin, alter user-owned custom-agent profiles, or inspect local rollout contents.
- Do not claim enforced read-only isolation when the host only offers a broader sandbox.

## Technical Plan and Ownership

| Requirement | Owner | Implementation |
| --- | --- | --- |
| R1-R3 | `scripts/select-agent-route.ps1` and `.sh` | Emit proportional review mode and whether fresh evidence is required. |
| R4-R5 | `scripts/validate-fresh-review-evidence.ps1` and template 33 | Validate reviewer identity, verdict, observed isolation, hashes, and verification evidence. |
| R6 | `scripts/codex-hooks/` | Track a passing validator in the turn state and block T4 completion without it. |
| R7 | pack 58, gates, runtime sequence, tests, and framework validator | Document the protocol, retain PowerShell/Unix route parity, and run it in the regression suite. |

No product data, network calls, browser session, deployment, or user-owned custom-agent profile is changed. The only operational state is task-local review evidence under `.ueef/evidence/`.

## Ordered Tasks

1. Add native protocol, template, attribution, and this specification.
2. Add validator and rejection-focused tests.
3. Extend route output and managed enforcement.
4. Register files, runtime guidance, documentation indexes, and regression tests.
5. Validate the source, runtime synchronization, installed runtime, and a real T3 evidence artifact.

## Acceptance Evidence

- `scripts/test-fresh-review-protocol.ps1` passes valid, changed-diff rejection, T4 non-fresh rejection, and T3 fallback cases.
- `scripts/test-agent-route.ps1` and `.sh` confirm the review mode for T3/T4 and cross-platform parity.
- `scripts/test-managed-enforcement.ps1` proves a T4 completion is blocked before and permitted after current-turn fresh-review validation.
- `scripts/validate-framework.ps1` passes with the protocol included in the runtime and documentation contracts.
