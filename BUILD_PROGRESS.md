# Build Progress

Current release: 2.19.0 (2026-07-29)

## Delivered baseline

- 62 framework packs, transactional runtime installation, activation/drift checks, and Windows/Unix validation surfaces.
- Pack 58 routing, Pack 59 workflow evidence, and Pack 60 opt-in specification workflows.
- 2.12.x added capability diagnostics, proportional selection, timed assurance, and structured health output.
- 2.13.x added task preflight, governed UI capability provenance, spec clarification/convergence artifacts, diff impact, and optional workflow utilities.
- 2.16.x reconciles intent-first routing across the source loader, master loader, Pack 58, quality gates, and generated runtime; it keeps narrow `T1` work single-agent by default and allows recorded higher reasoning only where justified.
- 2.19.0 unifies task classification, makes quality-gate scope tier-aware, separates source validation from runtime activation on Windows and Unix, replaces repeated generic contracts with domain-specific guidance, and adds behavioral routing and specificity evidence.
- Preferred UI, motion, frontend, and Hatch Pet skills now have one pinned manifest, missing-only installers, and capability-registry provenance.

## Evidence

- Source validation and nested deterministic tests pass for 2.19.0.
- The source checkout passes validation and reports `SOURCE_VALIDATED`; the managed runtime must be synchronized before it can claim `ACTIVE_RUNTIME`.
- Release work is pushed to `origin/main` after validation under the current autonomous delivery policy.

## Active delivery queue

1. Measure adoption and improve the Unix health/profile surface only with equivalent safe contracts.
2. Add adapters only when a real assistant integration requires one.
3. Evolve textual diff signals toward dependency graphs only with fixture-backed accuracy evidence.
