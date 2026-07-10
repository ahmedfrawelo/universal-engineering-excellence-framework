# Sizing System

Version: 1.2.0  
Status: Enforced  
Applies to: product UI, design systems, shared components, and AI-assisted implementation

## Purpose

Standardizes dimensions for controls, icons, cards, panels, dialogs, menus, tables, badges, and avatars.

## Required Practice

- Define minimum touch targets and named control sizes.
- Use min, max, aspect ratio, and content constraints instead of brittle fixed widths.
- Keep sizing compatible with zoom, localization, and responsive composition.

## Source-of-Truth Contract

Before creating or changing a visual or interactive element, inspect the project, its design-system source, component registry, shared components, shared services, and existing patterns. Reuse the closest approved capability first. Extend it when the semantic contract remains compatible. Generalize only when at least two real consumers justify the abstraction. Create a new capability only after recording why reuse and extension were rejected.

Every visual value and interaction rule must be represented by a named token, component contract, pattern, or documented exception. Exceptions require an owner, rationale, scope, expiry condition, and regression evidence.

## Verification Evidence

- [ ] Project, design-system, registry, and shared-service search is recorded.
- [ ] Token/component/pattern mapping is explicit.
- [ ] Theme, responsive, accessibility, behavior, and reuse evidence is attached.
- [ ] Automated or repeatable checks protect the contract.

## Failure Conditions

- Existing capability was not searched or was copied under a new name.
- A raw visual value or unsupported variant bypasses the source of truth.
- Critical theme, responsive, accessibility, or interaction behavior is unverified.

- A green build is used as proof of design compliance without inspection evidence.
- A visually similar duplicate is introduced under a new name.
- Hardcoded visual values or page-specific behavior bypass the governed source of truth.

## Related Pack

- framework/45-identity-access-application-models
- framework/46-design-system-consistency-reuse
- framework/47-theme-responsive-interaction-security-performance

## Completion Rule

This module passes only when the implementation is traceable to an approved token, component, pattern, or explicitly reviewed exception.
