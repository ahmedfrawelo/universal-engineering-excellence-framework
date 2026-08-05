# Fresh Context Review Protocol

## Purpose

Use a reviewer who did not produce the implementation to inspect the actual final diff and the verification evidence. The protocol catches assumptions that accumulated in the implementation context; it is not a claim of cross-model independence.

## Proportional Route

| Tier | Review mode | Requirement |
| --- | --- | --- |
| T0-T2 | `NONE` | The lead's focused review is sufficient unless the route escalates. |
| T3 | `FRESH_CONTEXT_RECOMMENDED` | Use for shared architecture, broad refactors, public contracts, or when the lead requests a commitment-boundary review. A documented direct-review fallback is allowed only when a fresh reviewer is unavailable. |
| T4 | `FRESH_CONTEXT_REQUIRED` | A fresh-context reviewer and a passing fresh-review evidence artifact are required before completion when the host exposes an eligible review lane. The lead triggers the selected review lane automatically as part of the route; do not stop to ask the user to request the reviewer manually. If no lane is exposed, record the capability gap and strengthen direct evidence; never claim independent review happened. |

Model families are runtime mappings. Do not hard-code a vendor, model name, or reasoning level in this protocol.

## Review Contract

The implementer or lead supplies the reviewer only the bounded packet below:

1. **Objective** â€” observable result and explicit non-goals.
2. **Ownership and interfaces** â€” exact changed paths, public contracts, and compatibility constraints.
3. **Final diff identity** â€” reviewed diff SHA-256 and before/after repository state identity.
4. **Verification evidence** â€” exact commands and observed results.
5. **Decision request** â€” `ship`, `fix-first`, or `rethink`.

The reviewer is behaviorally read-only. If the platform reports an enforced read-only sandbox, record it. If the host broadens the sandbox, capture exact before/after repository state and report behavioral read-only as a residual limitation. A reviewer must not implement a fix.

## Acceptance Rules

- The reviewer identity or thread id differs from every implementation thread id for a fresh review.
- The observed reviewer role, model capability, reasoning level when observable, sandbox policy, and permission profile are recorded without inventing unavailable fields.
- `ship` is valid only when the evidence supports the request. `fix-first` requires correction and a new review. `rethink` returns to architecture or specification work.
- The post-review diff hash must equal the reviewed diff hash. Any later mutation invalidates the verdict and requires a new review.
- Validate the artifact with `scripts/validate-fresh-review-evidence.ps1`. T4 completion is blocked by managed enforcement until that validator passes in the current turn.

## Evidence Artifact

Start from `framework/21-framework-resources/01-templates/33-fresh-review-evidence-template.json`. Store task-local evidence under `.ueef/evidence/`; do not place it in a project root or confuse it with product output.

## Boundaries

- This protocol strengthens, but does not replace, task evidence, completion audit, tests, security review, or lead accountability.
- Do not spawn a reviewer merely for ceremony. T3 uses it where the decision materially benefits; T4 follows the runtime route and available capability. When the route requires an eligible reviewer, run it automatically and record the evidence instead of asking the user for a separate trigger phrase.
- Do not substitute a different agent, model, or browser surface silently when an explicitly selected review route is unavailable.
- External workflow references inform this UEEF-native protocol; see `docs/third-party/sol-advisor-attribution.md`.
