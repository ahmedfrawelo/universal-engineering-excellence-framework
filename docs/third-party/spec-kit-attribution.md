# Spec Kit Attribution

UEEF 2.8.19 reviewed GitHub Spec Kit as an external reference for specification-driven development workflows. UEEF 2.25.9 refreshed that review without copying upstream material. UEEF 2.26.0 includes a provenance-tracked internal snapshot solely for manual comparison, update review, attribution, and license preservation. The UEEF runtime is independently implemented and never reads, imports, or executes that snapshot.

## Source

- Repository: `https://github.com/github/spec-kit`
- Documentation: `https://github.github.io/spec-kit/`
- Reviewed commit: `fd101d531eaec8a1e709db2f37632bc93b6ce4d6`
- Refresh reviewed HEAD: `03d71b336387b57b8dfb7d79777a6b65425a801c`
- Refresh observed tag range: up to `v0.9.5`
- Refresh access date: `2026-08-05`
- Vendored release: `v0.16.1`
- Vendored commit: `ad4104b56c219b0a27bac06547d1a3c7d6a0dbd6`
- Vendored access date: `2026-08-08`
- Vendored path: `engines/spec-workflow/upstream/spec-kit/`
- Provenance manifest: `engines/spec-workflow/UPSTREAM.json`
- License observed in the reviewed repository: MIT License, copyright GitHub, Inc.

## Historical idea-level reuse

Before the internal snapshot, UEEF did not copy Spec Kit templates, slash commands, or source files. It adapted general workflow ideas into UEEF-native rules:

- specification as the source of truth for substantial work.
- constitution or governing principles before technical planning.
- clarification and explicit ambiguity handling.
- requirement-to-plan-to-task traceability.
- checklist-style consistency analysis.
- convergence before final completion claims.
- optional task-to-issue export as a planning derivative, not an automatic external action.
- extension, preset, project-local override, and bundle governance as separate trust and precedence concepts.
- agent skill or slash-command interfaces as external surfaces mapped into UEEF-owned artifacts and validation.

## Vendored snapshot

The internal snapshot contains the official `src/specify_cli/` source tree, the official `workflows/speckit/workflow.yml`, upstream README and dependency metadata, and the upstream MIT license. Those files are copied without UEEF edits. The schema-v2 `UPSTREAM.json` pins the release, commit, file count, and an unambiguous length-prefixed aggregate content digest. `scripts/verify-spec-workflow-upstream.mjs` mechanically detects path or content drift and rejects links, hardlinks, non-portable paths, incomplete manifest coverage, and concurrent tree changes.

Community workflows and project-local custom steps are not imported automatically. The snapshot is never placed on the runtime `PYTHONPATH`, and no UEEF production command loads it. `scripts/review-spec-kit-update.ps1` performs a separate, explicit, manual review of candidate reference material; it is not a runtime bridge and cannot activate Spec Kit.

## UEEF-owned independent engine

UEEF-specific behavior lives under `engines/spec-workflow/ueef/` and remains independently reviewable:

- validated DAG task model with dependency-cycle detection;
- durable `PENDING`, `READY`, `RESERVED`, `RUNNING`, `BLOCKED`, `DONE`, and `FAILED` state;
- atomic persistence, graph-drift refusal, resume, optimistic revisions, and bounded retry;
- conflict-aware execution waves and dynamic team targets bounded by tier, risk, worker limits, and token budget;
- host-neutral Codex, Claude, and generic dispatch contracts with explicit write ownership and acceptance evidence;
- a hard default denial for upstream shell-step definitions and no shell execution command.

## Independence boundary

Spec Kit remains an external project and its snapshot is not an engine input. UEEF's `framework/19-agent-workflow/03-spec-driven-development/` and `engines/spec-workflow/ueef/` exclusively own runtime policy, file ownership, scheduling, quality gates, and convergence. Installing or importing external templates, skills, commands, presets, extensions, bundles, or Spec Kit Python dependencies is not part of UEEF runtime operation.
