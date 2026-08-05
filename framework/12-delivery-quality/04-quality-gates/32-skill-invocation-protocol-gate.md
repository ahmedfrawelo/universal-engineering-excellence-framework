# Skill Invocation Protocol Gate

## Purpose

Verifies that relevant skills and workflow packs were checked before non-trivial work.

## Checks

- Relevant installed skills and project-local skills were detected.
- The selected skill chain is minimal and task-specific.
- Any skipped obvious skill has a concrete reason.
- Red flags were corrected before implementation continued.
- TDD or an equivalent evidence loop was used where appropriate.
- Subagents, if used, had bounded ownership and independent evidence.
- External skill sources were attributed and not copied wholesale.

## Pass Criteria

The task has a clear skill-routing decision and verification evidence that matches the selected workflow.
