# Spec Kit Attribution

UEEF 2.8.19 reviewed GitHub Spec Kit as an external reference for specification-driven development workflows. UEEF 2.25.9 refreshed that review against the current public repository state without copying upstream templates, slash commands, or source files.

## Source

- Repository: `https://github.com/github/spec-kit`
- Documentation: `https://github.github.io/spec-kit/`
- Reviewed commit: `fd101d531eaec8a1e709db2f37632bc93b6ce4d6`
- Refresh reviewed HEAD: `03d71b336387b57b8dfb7d79777a6b65425a801c`
- Refresh observed tag range: up to `v0.9.5`
- Refresh access date: `2026-08-05`
- License observed in the reviewed repository: MIT License, copyright GitHub, Inc.

## What UEEF Reused

UEEF did not copy Spec Kit templates, slash commands, or source files. It adapted general workflow ideas into UEEF-native rules:

- specification as the source of truth for substantial work.
- constitution or governing principles before technical planning.
- clarification and explicit ambiguity handling.
- requirement-to-plan-to-task traceability.
- checklist-style consistency analysis.
- convergence before final completion claims.
- optional task-to-issue export as a planning derivative, not an automatic external action.
- extension, preset, project-local override, and bundle governance as separate trust and precedence concepts.
- agent skill or slash-command interfaces as external surfaces mapped into UEEF-owned artifacts and validation.

## Integration Boundary

Spec Kit remains an external project. UEEF's `framework/19-agent-workflow/03-spec-driven-development/` is independently written and validated against UEEF runtime, file ownership, skill invocation, quality-gate, and delivery-continuation rules. Installing the external Spec Kit CLI, templates, skills, commands, presets, extensions, or bundles is not automatic and requires explicit task scope.
