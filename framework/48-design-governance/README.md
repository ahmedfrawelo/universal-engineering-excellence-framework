# Design Governance

Version: 1.2.0  
Status: Enforced  
Applies to: product UI, design systems, shared components, and AI-assisted implementation

## Purpose

Establishes one design language, token system, component library, interaction language, responsive strategy, and source of truth for every product UI.

## Required Practice

- Use this pack with packs 46 and 47; pack 48 governs design decisions while pack 47 governs theme, responsive, interaction, security, and performance contracts.
- Search before creating; reuse before extending; extend before generalizing; generalize before creating new.
- Treat the quality gate as release-blocking for applicable UI work.

## Source-of-Truth Contract

Before creating or changing a visual or interactive element, inspect the project, its design-system source, component registry, shared components, shared services, and existing patterns. Reuse the closest approved capability first. Extend it when the semantic contract remains compatible. Generalize only when at least two real consumers justify the abstraction. Create a new capability only after recording why reuse and extension were rejected.

Every visual value and interaction rule must be represented by a named token, component contract, pattern, or documented exception. Exceptions require an owner, rationale, scope, expiry condition, and regression evidence.

## Verification Evidence

- [ ] The loader selects the pack for UI and design tasks.
- [ ] All 29 numbered modules plus README and INDEX exist and are non-empty.
- [ ] Core, runtime, registry, and validation reference the pack.

## Failure Conditions

- The pack is used to replace a valid existing product identity without evidence.
- Guidance is copied into feature code instead of applied through shared contracts.
- Design compliance is claimed without direct evidence.

- A green build is used as proof of design compliance without inspection evidence.
- A visually similar duplicate is introduced under a new name.
- Hardcoded visual values or page-specific behavior bypass the governed source of truth.

## Related Pack

- framework/45-identity-access-application-models
- framework/46-design-system-consistency-reuse
- framework/47-theme-responsive-interaction-security-performance

## Completion Rule

This module passes only when the implementation is traceable to an approved token, component, pattern, or explicitly reviewed exception.
