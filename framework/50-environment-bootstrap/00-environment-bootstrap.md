# Environment Bootstrap

Version: 1.4.0
Status: Enforced

## Purpose

Inspects and repairs the engineering environment before any task phase.

## Required Practice

- Run before inspection, architecture detection, planning, implementation, and gates.
- Core and AI profiles are mandatory; task-relevant profiles are evidence-selected; readiness is never assumed.
- Classify every dependency as Mandatory, Recommended, or Optional.
- Emit Environment Ready, Profiles Loaded, Mandatory Dependencies, Recommended Dependencies, Optional Dependencies, Missing Items, Installation Performed, and Validation Result.

## Evidence

- [ ] Current command, path, version, skill, MCP, or runtime evidence is recorded.
- [ ] Profile selection is traceable to task or repository evidence.
- [ ] READY/BLOCKED/WARN matches the dependency policy.

## Failure Conditions

- Mandatory gaps are ignored or hidden.
- The checker claims readiness without current evidence.
- A fixed universal tool list blocks unrelated work.

## Related Modules

- framework/01-core/01-master-loader.md
- framework/03-runtime/00-runtime-sequence.md
- framework/50-environment-bootstrap/10-dependency-levels.md
