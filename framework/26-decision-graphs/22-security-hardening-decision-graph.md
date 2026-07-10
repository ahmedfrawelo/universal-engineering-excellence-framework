# Security Hardening Decision Graph

Version: 1.1.0

## Inputs

- assets; actors; trust boundaries; data sensitivity; tenant model; abuse cases

## Alternatives

- prevent; detect; limit; isolate; audit; recover

## Tradeoffs

Choose the option that preserves semantics and ownership while meeting measured user, security, and operational needs. Prefer reversible changes when evidence is incomplete.

## Risks

- client-only checks fail; broad privilege increases blast radius; excessive friction can create unsafe bypasses

## Recommended Default

deny by default at server boundaries with least privilege and layered verification.

## Exceptions

An exception requires project evidence, an owner, a review date, bounded impact, and a regression test.

## Failure Modes

- Selecting by visual preference without repository evidence.
- Applying a local patch that bypasses the shared contract.
- Declaring success without testing the relevant edge and failure paths.

## Related Modules

- framework/46-design-system-consistency-reuse/09-reuse-decision-engine.md
- framework/47-theme-responsive-interaction-security-performance/README.md
