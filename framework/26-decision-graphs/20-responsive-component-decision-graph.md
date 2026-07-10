# Responsive Component Decision Graph

Version: 1.1.0

## Inputs

- content priority; minimum width; comparison needs; input modes; localization

## Alternatives

- wrap; reflow; collapse; disclose; scroll; virtualize; switch composition

## Tradeoffs

Choose the option that preserves semantics and ownership while meeting measured user, security, and operational needs. Prefer reversible changes when evidence is incomplete.

## Risks

- hiding content loses capability; uncontrolled scrolling harms usability; alternate markup can duplicate behavior

## Recommended Default

use component-owned reflow and disclosure; preserve semantics and one behavior source.

## Exceptions

An exception requires project evidence, an owner, a review date, bounded impact, and a regression test.

## Failure Modes

- Selecting by visual preference without repository evidence.
- Applying a local patch that bypasses the shared contract.
- Declaring success without testing the relevant edge and failure paths.

## Related Modules

- framework/46-design-system-consistency-reuse/09-reuse-decision-engine.md
- framework/47-theme-responsive-interaction-security-performance/README.md
