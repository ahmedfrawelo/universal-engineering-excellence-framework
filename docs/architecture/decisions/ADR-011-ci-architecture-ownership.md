# ADR-011: CI Architecture Ownership

## Status

Accepted.

## Date

2026-08-06

## Context

UEEF validates changed paths against `config/architecture-policy.json`. The policy already assigns source, framework, automation, tooling, and documentation owners, but it did not assign `.github/`. Adding the embedded repository engine's full locked pytest and Ruff job therefore left the workflow structurally unowned even though file-organization policy placed it under `.github/workflows`.

## Decision

Add a dedicated `ci` architecture owner for `.github/`. CI may depend on core configuration, framework contracts, automation scripts, tools, and its own workflow definitions. Product and runtime implementation remain in their existing owners; the CI owner only orchestrates their verification.

## Consequences

- Workflow changes receive an explicit architecture owner.
- Architecture reports can evaluate CI changes without an unowned-path warning.
- CI orchestration does not become a source owner or absorb implementation logic.
- Future workflow dependencies outside the allowed owner set remain violations.

## Rollback

Remove the `ci` owner and dependency rule together with this ADR. Any remaining `.github/` changes must then be assigned to another explicit architecture owner before passing the architecture gate.
