# Overlay Behavior Decision Graph

Version: 1.1.0

## Inputs

- overlay purpose; modality; anchor; viewport; dismissal risk; focus needs

## Alternatives

- tooltip; dropdown; popover; drawer; dialog; inline disclosure

## Tradeoffs

Choose the option that preserves semantics and ownership while meeting measured user, security, and operational needs. Prefer reversible changes when evidence is incomplete.

## Risks

- wrong semantics breaks keyboard use; outside dismissal can lose work; stacking creates traps

## Recommended Default

choose the least disruptive semantic surface and apply the shared overlay coordinator.

## Exceptions

An exception requires project evidence, an owner, a review date, bounded impact, and a regression test.

## Failure Modes

- Selecting by visual preference without repository evidence.
- Applying a local patch that bypasses the shared contract.
- Declaring success without testing the relevant edge and failure paths.

## Related Modules

- framework/46-design-system-consistency-reuse/09-reuse-decision-engine.md
- framework/47-theme-responsive-interaction-security-performance/README.md
