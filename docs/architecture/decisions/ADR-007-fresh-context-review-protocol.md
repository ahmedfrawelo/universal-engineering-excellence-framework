# ADR-007: Add proportional fresh-context review to UEEF orchestration

Status: Accepted
Date: 2026-08-03

## Context

UEEF routes agent topology and retains lead accountability, but its final evidence did not bind an independently reviewed verdict to the exact final diff. Broad or critical work can accumulate assumptions in the implementation context even when tests pass.

## Decision

- Add a UEEF-native fresh-context review protocol in pack 58.
- Keep capability classes and runtime observation model-neutral; do not pin a vendor, model name, or user-owned custom-agent profile.
- Emit `FRESH_CONTEXT_RECOMMENDED` for T3 and `FRESH_CONTEXT_REQUIRED` for T4 routes.
- Require a machine-validatable artifact with distinct reviewer identity, verdict, observed isolation context, verification evidence, and matching reviewed/post-review diff hashes.
- Managed enforcement blocks T4 completion until current-turn fresh-review validation passes. T3 may use an explicit direct-review fallback only when no eligible review lane is exposed.

## Consequences

Fresh review is an evidence-backed delivery gate rather than an advisory note. T0-T2 remain economical, T3 receives proportional review, and T4 cannot silently represent a lead review as independent review. A later diff mutation invalidates the earlier verdict.

## Alternatives rejected

- Installing an external orchestration plugin: would add platform-specific custom-agent files, Unix tooling, and fixed model names.
- Forcing a high-reasoning implementation subagent for every task: conflicts with UEEF's proportional T0/T1 routing.
- Treating a requested read-only sandbox as proof: host policy can broaden it, so UEEF records observed state instead.
