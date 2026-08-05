# Ux Gate

## Pass Conditions

- The required ux outcome and acceptance boundary are explicit.
- The implementation conforms to repository ownership and conventions.
- Review covers user goal, task flow, comprehension, feedback, recovery, and effort.
- task-based review covering success, error, cancellation, and recovery is current, reproducible, and successful.
- Residual risk has a named owner, mitigation, and trigger.

## Hard Failures

- A critical ux invariant, safety control, or acceptance behavior is missing or contradicted.
- Required validation failed, was skipped without cause, or cannot be reproduced.
- Compatibility, destructive impact, public behavior, or rollback remains unknown.
- Completion depends on a placeholder, fabricated result, or undocumented manual assumption.

## Evidence Record

Record inspected artifacts, exact commands or review method, results, exceptions, and the reviewer or automation source. A warning remains a warning; it cannot be averaged into a pass.

## Decision

Return PASS, FAIL, or BLOCKED. BLOCKED must name the missing fact or authority and the smallest action that can resolve it.
