# TDD and Evidence Loop

## Purpose

Use tests and observable evidence to prevent optimistic completion. TDD is required when the risk and project tooling make it practical; otherwise the assistant must still create an evidence loop.

## TDD Fit

Prefer test-first work when:

- Fixing a reproducible bug.
- Adding domain logic, validation, parsing, calculations, API behavior, data mapping, or permissions.
- Changing shared reusable behavior.
- Modifying code where an existing test harness is already present.

## Evidence Loop

1. Reproduce or define the expected failure.
2. Add the smallest focused test or check.
3. Confirm it fails when possible.
4. Implement the minimal fix.
5. Confirm the targeted test passes.
6. Run the nearest regression check.
7. Refactor only after green evidence.

## When Test-First Is Not Practical

Record why and use another evidence source: typecheck, build, focused script, visual proof, API call, browser verification, or static inspection with file references.

## Anti-Patterns

- Writing broad tests that only prove implementation details.
- Fixing multiple hypotheses at once.
- Deleting or weakening tests to pass.
- Claiming behavior without current evidence.
