# Delivery Continuation Policy

An expanded request is not a reason to pause implementation. When the user explicitly broadens work from an incremental change to a redesign, migration, rebuild, or larger integration, update the plan and continue toward the requested end state.

## Required Behavior

- Separate implementation readiness from release readiness. A feature may be under construction and not deployable yet; that does not block coding, testing, or incremental verification.
- If scope expands, inspect the newly affected paths, revise the plan, and deliver the next coherent vertical slice. Do not stop merely because the work is larger than the original estimate.
- Use `BLOCKED` only for a real impasse: missing required access, an unavailable mandatory dependency, an unresolved destructive decision, or an external condition that prevents meaningful progress.
- Internal implementation failures are never a real impasse while repository access and normal engineering tools remain available. Compile errors, failing tests, API/facade/schema mismatches, save-contract bugs, incomplete wiring, and repeated unsuccessful patches require root-cause analysis, replanning, escalation, or a bounded verifier; they do not justify pausing or blocking the goal.
- Repetition does not convert an internal bug into an external blocker. After repeated failure, change the diagnostic approach and continue meaningful work.
- Mark a goal `BLOCKED` only when the blocking condition is external or requires a user-only decision/action and no meaningful local implementation, investigation, testing, or documentation work remains.
- A task-local Node REPL or browser-client failure is internal control-channel degradation, not a Chrome outage. It cannot justify a `BLOCKED` transition or requesting a Chrome restart unless external Chrome unavailability is independently proven.
- Missing screenshot evidence, pCloud screenshot delay, or task-local Chrome control degradation is not a valid `BLOCKED` transition when implementation, build, non-visual tests, source inspection, or documentation can continue or have passed. Use `ACTIVE` for ongoing work or `PARTIAL` in status-only reporting when the only missing gate is visual verification.
- Never stop and wait for the user merely to resume an incomplete code path. If a goal was incorrectly paused for an internal failure, resume it immediately and continue from current state.

## Goal Transition Contract

`BLOCKED_ALLOWED = repeated_external_condition AND no_meaningful_local_work_remaining AND user_or_external_state_change_required`

Compile failures, test failures, API/facade/schema mismatches, save-contract bugs, incomplete wiring, regressions, unsuccessful patches, pending screenshots, pCloud screenshot delays, and task-local Chrome control degradation never satisfy `repeated_external_condition`.

`FINAL_ALLOWED = requested_outcome_complete OR user_requested_status_only OR GoalStatus_COMPLETE OR BLOCKED_ALLOWED`

## Stop When Done

When the user asks a bounded question, review, or change and that requested outcome is complete, give the final answer immediately. Do not extend the task with optional improvements, audits, upgrades, or adjacent implementation merely because work could continue. Continuation applies only to explicit multi-step implementation work that remains within the requested scope.

Do not repeat the same safety, deletion, cleanup, or progress status message across assistant updates. If a bounded request has no remaining in-scope action, replace "continuing" language with a final answer that states the verified outcome once. Repeated status phrasing is a control-flow failure; stop, summarize the evidence, and close when `FINAL_ALLOWED` is true.

When `GoalStatus` is `ACTIVE`, do not emit a final answer saying the work is incomplete, no result exists, work remains, or execution will continue later. Send a concise commentary progress update and continue execution in the same goal run. Before any final answer on a goal task, read current goal status and reject finalization unless `FINAL_ALLOWED` is true.
- A known regression blocks claiming completion or release. It does not block working on the fix unless continuing would worsen or destroy user data.
- Do not substitute a status message such as "not ready to release" for implementation work the user requested.

## User-Facing Behavior

State progress and evidence, then continue. If a release is not ready, say what remains for release while still completing the requested code path.

## Long Goal Progress Reporting

For a long-running user goal, status updates must be useful progress reports, not heartbeat messages.

- Give a concise progress update after each material milestone, long verification step, scope change, or meaningful blocker analysis.
- Include an approximate completion percentage when the work can be estimated from the current plan. If a percentage would be fake precision, report the completed phase count instead.
- A good progress update states: current percent or phase, completed work, current action, next gate, and the latest concrete evidence.
- Do not send a progress update if no new evidence, completed step, failed check, or changed plan exists since the previous update.
- Do not imply completion from percentage alone. Final completion still requires the requested outcome, required gates, and recorded verification.
- Use conservative estimates: discovery and planning should not exceed 30%, implementation should not exceed 75% before relevant validation, and validation/release should not exceed 95% until final gates pass.
- If the goal changes scope, recalculate progress against the new scope and say that the estimate changed because the scope changed.

Recommended compact format:

```text
Progress: <percent or phase>
Done: <new completed evidence>
Now: <current action>
Next: <next gate>
```
