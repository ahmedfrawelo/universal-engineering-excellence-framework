# Engineering Guardian Gate

Version: 1.3.0  
Status: Release blocking

## Pass Conditions

- The affected baseline, scope, and regression monitors are recorded.
- Architecture, security, performance, scalability, maintainability, UI, UX, accessibility, reliability, documentation, tests, and developer experience are checked where applicable.
- No quality dimension is worse without an explicit, owned, time-bounded risk decision.
- Unresolved High or Critical security findings fail the gate.
- Critical performance, accessibility, contract, data, or production regressions fail the gate.
- Nearby obvious low-risk improvements are made or documented with a reason they are out of scope.
- Self-criticism and final guardian checklist are complete.

## Required Evidence

Record before-and-after checks, test commands, security reports, performance measurements, UI or interaction evidence, architecture review, documentation updates, and rollback or mitigation triggers.

## Hard Failures

Known regression, silent technical-debt increase, duplicate behavior, broken contract, unowned risk, critical security issue, critical performance regression, or claim without evidence means FAIL. A green build cannot override this gate.
