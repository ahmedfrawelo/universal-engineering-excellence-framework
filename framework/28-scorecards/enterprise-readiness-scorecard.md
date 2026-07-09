# Enterprise Readiness Scorecard

## Purpose
This scorecard converts review quality into a repeatable evaluation. Use it after implementation and quality gates to decide whether the work is ready, partial, or blocked.

## Scoring Scale
- 0: Not addressed or contradicted by the implementation.
- 1: Mentioned but shallow, unverified, or missing important edge cases.
- 2: Mostly addressed with some evidence and manageable limitations.
- 3: Fully addressed with clear evidence, tests, and maintainable design.

## Evaluation Criteria
1. Requirement fit: the result solves the actual request and preserves stated constraints.
2. Local consistency: the work follows existing project architecture, naming, styling, and tooling.
3. Simplicity: the solution avoids unnecessary abstraction, duplication, and speculative features.
4. Security: inputs, permissions, secrets, dependencies, and failure paths are safe by default.
5. Performance: the design avoids wasteful rendering, queries, network calls, memory growth, and blocking work.
6. Reliability: errors, retries, rollback, migrations, and observability are considered where relevant.
7. Testability: validation is automated where practical and manual evidence is explicit.
8. Documentation: user-facing and maintainer-facing changes are documented without noise.

## Passing Threshold
Score at least 18 out of 24 overall, with no zero in security, reliability, or requirement fit. A release or production change should target 21 or higher.

## Evidence
Record inspected files, validation commands, screenshots, logs, commits, and known limitations. Evidence must be specific enough for another engineer to reproduce the review.

## Review Notes
If the score is partial, identify the smallest additional work that would move the review to pass. If the score is fail, stop and fix the root issue before reporting completion.
