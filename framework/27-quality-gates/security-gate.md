# Security Gate

## Pass Conditions

- The required security outcome and acceptance boundary are explicit.
- The implementation conforms to repository ownership and conventions.
- Review covers asset, actor, trust boundary, threat, prevention, detection, response, and safe failure.
- negative-path tests, authorization checks, secret scanning, and exposure review is current, reproducible, and successful.
- Residual risk has a named owner, mitigation, and trigger.

## Hard Failures

- A critical security invariant, safety control, or acceptance behavior is missing or contradicted.
- Required validation failed, was skipped without cause, or cannot be reproduced.
- Compatibility, destructive impact, public behavior, or rollback remains unknown.
- Completion depends on a placeholder, fabricated result, or undocumented manual assumption.

## Evidence Record

Record inspected artifacts, exact commands or review method, results, exceptions, and the reviewer or automation source. A warning remains a warning; it cannot be averaged into a pass.

## Decision

Return PASS, FAIL, or BLOCKED. BLOCKED must name the missing fact or authority and the smallest action that can resolve it.
