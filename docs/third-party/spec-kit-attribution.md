# Spec Kit Attribution

UEEF 2.8.19 reviewed GitHub Spec Kit as an external reference for specification-driven development workflows.

## Source

- Repository: `https://github.com/github/spec-kit`
- Documentation: `https://github.github.io/spec-kit/`
- Reviewed commit: `fd101d531eaec8a1e709db2f37632bc93b6ce4d6`
- License observed in the reviewed repository: MIT License, copyright GitHub, Inc.

## What UEEF Reused

UEEF did not copy Spec Kit templates, slash commands, or source files. It adapted general workflow ideas into UEEF-native rules:

- specification as the source of truth for substantial work.
- constitution or governing principles before technical planning.
- clarification and explicit ambiguity handling.
- requirement-to-plan-to-task traceability.
- checklist-style consistency analysis.
- convergence before final completion claims.

## Integration Boundary

Spec Kit remains an external project. UEEF's `framework/60-spec-driven-development/` is independently written and validated against UEEF runtime, file ownership, skill invocation, quality-gate, and delivery-continuation rules.
