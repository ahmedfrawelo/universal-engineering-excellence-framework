# Design Governance Index

Version: 1.2.0  
Status: Enforced  
Applies to: product UI, design systems, shared components, and AI-assisted implementation

## Purpose

Routes design governance work from principles and tokens through components, layouts, themes, interactions, overlays, drift, reuse, and release review.

## Required Practice

- Start with 00, 02, 15, 16, and 25 for a new UI capability.
- Select the token family and component/pattern contract that owns the change.
- Finish with 26, 27, and 28.

## Source-of-Truth Contract

Before creating or changing a visual or interactive element, inspect the project, its design-system source, component registry, shared components, shared services, and existing patterns. Reuse the closest approved capability first. Extend it when the semantic contract remains compatible. Generalize only when at least two real consumers justify the abstraction. Create a new capability only after recording why reuse and extension were rejected.

Every visual value and interaction rule must be represented by a named token, component contract, pattern, or documented exception. Exceptions require an owner, rationale, scope, expiry condition, and regression evidence.

## Verification Evidence

- [ ] Every numbered module is linked or discoverable.
- [ ] The pack is cross-referenced from the Master Loader and Master Index.

## Failure Conditions

- A UI change has no governance owner or source-of-truth path.
- A module is selected solely by file name without task evidence.

- A green build is used as proof of design compliance without inspection evidence.
- A visually similar duplicate is introduced under a new name.
- Hardcoded visual values or page-specific behavior bypass the governed source of truth.

## Related Pack

- framework/45-identity-access-application-models
- framework/46-design-system-consistency-reuse
- framework/47-theme-responsive-interaction-security-performance

## Completion Rule

This module passes only when the implementation is traceable to an approved token, component, pattern, or explicitly reviewed exception.
