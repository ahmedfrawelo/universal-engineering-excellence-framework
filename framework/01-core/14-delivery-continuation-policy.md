# Delivery Continuation Policy

An expanded request is not a reason to pause implementation. When the user explicitly broadens work from an incremental change to a redesign, migration, rebuild, or larger integration, update the plan and continue toward the requested end state.

## Required Behavior

- Separate implementation readiness from release readiness. A feature may be under construction and not deployable yet; that does not block coding, testing, or incremental verification.
- If scope expands, inspect the newly affected paths, revise the plan, and deliver the next coherent vertical slice. Do not stop merely because the work is larger than the original estimate.
- Use `BLOCKED` only for a real impasse: missing required access, an unavailable mandatory dependency, an unresolved destructive decision, or an external condition that prevents meaningful progress.
- A known regression blocks claiming completion or release. It does not block working on the fix unless continuing would worsen or destroy user data.
- Do not substitute a status message such as "not ready to release" for implementation work the user requested.

## User-Facing Behavior

State progress and evidence, then continue. If a release is not ready, say what remains for release while still completing the requested code path.
