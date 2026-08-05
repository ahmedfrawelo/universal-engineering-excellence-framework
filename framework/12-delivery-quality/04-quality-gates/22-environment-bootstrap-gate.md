# Environment Bootstrap Gate

Version: 1.4.0  
Status: Release blocking before engineering begins

## Pass Conditions

- Bootstrap ran before project inspection, architecture detection, planning, implementation, and quality gates.
- Core and AI profiles were checked.
- Task-relevant profiles were selected from evidence rather than a fixed universal tool list.
- Every selected Mandatory dependency passed or was safely repaired.
- Recommended gaps are visible as WARN and Optional gaps are non-blocking.
- UEEF runtime, loader, validators, tools, skills, and relevant MCPs have current evidence.

## Fail Conditions

Fail and stop when any selected Mandatory dependency is missing or cannot be safely installed. Never silently skip a required tool, skill, runtime, loader, validator, or MCP.
