# Incident Report Template

## Purpose
Use this template when planning, implementing, or reviewing this class of engineering work. The template forces the AI assistant and human reviewer to capture scope, constraints, evidence, and acceptance criteria before changes are treated as complete.

## Required Inputs
- User request and business intent.
- Current repository path, stack, runtime, and deployment target.
- Existing conventions, related modules, and ownership boundaries.
- Security, performance, accessibility, and compatibility constraints.
- Tests, build commands, and validation commands available in the project.

## Required Sections
1. Context: summarize the current implementation path and the reason for the change.
2. Scope: list what will change and what will not be touched.
3. Design: describe the chosen approach, alternatives rejected, and dependencies affected.
4. Implementation plan: order the work into small reviewable steps.
5. Risk review: identify data loss, security, performance, UX, migration, and rollback risks.
6. Validation: name exact lint, typecheck, build, unit, integration, e2e, security, and manual checks.
7. Acceptance criteria: define observable pass/fail conditions.
8. Final review: document evidence, remaining limitations, and follow-up actions.

## Checklist
- The plan is based on inspected project code, not assumptions.
- The design reuses existing patterns before adding new abstractions.
- Error states, edge cases, and rollback behavior are covered.
- Security and privacy implications are explicitly reviewed.
- Performance impact is measured or reasoned from concrete code paths.
- Documentation, examples, and tests are updated when behavior changes.
- The final response reports exactly what was verified and what was not.

## Quality Gate
Do not proceed to completion until the related quality gate passes. If evidence is unavailable, record the gap as a limitation and recommend the smallest practical verification step.

## Output Format
- Summary: one paragraph.
- Changes: concise list of affected files or modules.
- Evidence: commands, screenshots, logs, or review notes.
- Risks: remaining concerns and mitigation.
- Decision: pass, partial, or fail.
