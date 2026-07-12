# Delivery Continuation Policy

An expanded request is not a reason to pause implementation. When the user explicitly broadens work from an incremental change to a redesign, migration, rebuild, or larger integration, update the plan and continue toward the requested end state.

## Required Behavior

- Separate implementation readiness from release readiness. A feature may be under construction and not deployable yet; that does not block coding, testing, or incremental verification.
- If scope expands, inspect the newly affected paths, revise the plan, and deliver the next coherent vertical slice. Do not stop merely because the work is larger than the original estimate.
- Use `BLOCKED` only for a real impasse: missing required access, an unavailable mandatory dependency, an unresolved destructive decision, or an external condition that prevents meaningful progress.
- Internal implementation failures are never a real impasse while repository access and normal engineering tools remain available. Compile errors, failing tests, API/facade/schema mismatches, save-contract bugs, incomplete wiring, and repeated unsuccessful patches require root-cause analysis, replanning, escalation, or a bounded verifier; they do not justify pausing or blocking the goal.
- Repetition does not convert an internal bug into an external blocker. After repeated failure, change the diagnostic approach and continue meaningful work.
- Mark a goal `BLOCKED` only when the blocking condition is external or requires a user-only decision/action and no meaningful local implementation, investigation, testing, or documentation work remains.
- Never stop and wait for the user merely to resume an incomplete code path. If a goal was incorrectly paused for an internal failure, resume it immediately and continue from current state.

## Goal Transition Contract

`BLOCKED_ALLOWED = repeated_external_condition AND no_meaningful_local_work_remaining AND user_or_external_state_change_required`

Compile failures, test failures, API/facade/schema mismatches, save-contract bugs, incomplete wiring, regressions, and unsuccessful patches never satisfy `repeated_external_condition`.
- A known regression blocks claiming completion or release. It does not block working on the fix unless continuing would worsen or destroy user data.
- Do not substitute a status message such as "not ready to release" for implementation work the user requested.

## User-Facing Behavior

State progress and evidence, then continue. If a release is not ready, say what remains for release while still completing the requested code path.
