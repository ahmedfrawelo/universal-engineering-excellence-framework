# Design Governance Gate

Version: 1.2.0  
Status: Release blocking for applicable UI work

## Pass Conditions

- Existing project UI, design-system source, component registry, shared components, shared services, and pattern library were searched.
- Reuse, extension, generalization, or new-creation decision is documented with rejected alternatives.
- Every color, typography role, icon, spacing, size, radius, border, shadow, elevation, motion, opacity, and layer value maps to a governed token or approved exception.
- Components and patterns have an owner, contract, supported states, theme coverage, responsive behavior, accessibility behavior, and regression evidence.
- Theme, responsive, interaction, overlay, accessibility, performance, and no-reinvention requirements pass the relevant pack 47 and 48 checks.

## Fail Conditions

Fail if a new component duplicates an existing capability, raw visual values bypass tokens, typography or icons are inconsistent, page-specific behavior replaces shared behavior, existing components were not inspected, theme or responsive behavior is missing, overlays diverge, or design drift lacks an owner and remediation path. A build passing alone is insufficient.

## Evidence

Record search paths, registry entries, token mapping, design review output, tests, screenshots or interaction traces, scorecard result, and approved exceptions.
