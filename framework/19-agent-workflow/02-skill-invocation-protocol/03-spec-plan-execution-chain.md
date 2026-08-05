# Spec Plan Execution Chain

## Purpose

Complex work needs a thin but real chain from understanding to implementation. The chain must be proportional to task size and must not turn small fixes into ceremony.

## Chain

1. **Clarify outcome:** define the user-visible result and non-goals.
2. **Inspect context:** read relevant code, docs, tests, and project conventions.
3. **Draft plan:** list implementation steps, ownership boundaries, and checks.
4. **Execute:** keep changes scoped and update the plan as evidence changes.
5. **Review:** compare result against the requested outcome, not only against the build.
6. **Verify:** run targeted checks and report limits honestly.

## Plan Quality

- Use exact files or ownership areas when known.
- Keep tasks small enough to review.
- Include tests or validation for each behavior-changing step.
- Include a rollback or cleanup note for generated outputs, migrations, deployments, and browser sessions.

## Anti-Patterns

- Writing a large spec for a tiny typo fix.
- Coding from memory when the repository has an established pattern.
- Delegating a task without supplying the relevant spec text.
- Continuing after discovering the plan contradicts the codebase.
