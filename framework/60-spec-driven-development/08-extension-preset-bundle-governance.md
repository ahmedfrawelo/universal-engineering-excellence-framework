# Extension, Preset, and Bundle Governance

## Purpose

Spec-driven workflows often need customization. This module separates new capability, workflow customization, and role/team packaging so the assistant does not blur trust boundaries.

## Definitions

- Extension: adds a new capability, phase, command, integration, or artifact type.
- Preset: customizes templates, terminology, gates, or defaults without adding a new capability.
- Bundle: combines extensions, presets, skills, modules, and roles for a team or workflow.

## Rules

- Do not treat a preset as a capability. If the user needs new behavior, create or select an extension-like owner.
- Do not treat a bundle as a single trusted source. Review each included component, license, and permission boundary.
- Project-local overrides have the narrowest blast radius and should be preferred for one-off adjustments.
- Shared organization presets must include version, owner, compatibility, rollback, and changelog notes.
- Community or third-party components require source review before installation or incorporation.
- Removal must be reversible: document what falls back to the next active override, preset, extension, or core default.

## Packaging Requirements

- Manifest or index with name, version, owner, purpose, files, and compatibility.
- License and attribution references.
- Install/update/remove behavior.
- Validation command or manual review path.
- Security and permission notes for any tool, connector, script, or network behavior.
