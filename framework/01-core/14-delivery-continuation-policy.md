# Delivery Continuation Policy

An expanded request is not a reason to pause implementation. When the user explicitly broadens work from an incremental change to a redesign, migration, rebuild, or larger integration, update the plan and continue toward the requested end state.

## Required Behavior

- Separate implementation readiness from release readiness. A feature may be under construction and not deployable yet; that does not block coding, testing, or incremental verification.
- If scope expands, inspect the newly affected paths, revise the plan, and deliver the next coherent vertical slice. Do not stop merely because the work is larger than the original estimate.
- A goal update is routed before execution. Do not reflexively abandon the active step: merge current-step updates, round-trip through verified prior-step corrections using a saved resume point, queue future-step updates in dependency order, and pause/replan only when the update invalidates current work. Material conflicts preserve state and require user clarification.
- Record that every update was detected and classified. During final comparison, missing requested behavior is implementation work, not a documentation note: keep the goal active, implement it in its routed step, restore the resume point when applicable, and repeat comparison.
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

`COMPLETE_ALLOWED = requested_outcome_complete AND no_required_work_remaining AND gates_pass AND verification_recorded AND completion_audit_passed`

`FINAL_ALLOWED = user_requested_status_only OR COMPLETE_ALLOWED OR BLOCKED_ALLOWED`

`completion_audit_passed` requires a schema-version-2 audit whose verbatim source review covers every non-whitespace character of the original goal with contiguous, exact `start`/`end` segments, classifies every segment, links every segment to a requirement, and links every requirement to passing acceptance criteria with current evidence. It also requires an announced `implementation complete -> goal review started` transition while the goal remained `ACTIVE`, an inventory of actual implemented/observed behavior, a checked goal-to-actual-implementation comparison for every requirement, requested-implementation and best-feasible-outcome passes, no untraced implementation, and a changed-surface regression review with no remaining task-caused regression. Unrelated findings are recorded with evidence and an out-of-scope reason but are not repaired. `remainingWork` and `knownProblems` must be empty. Self-declared completion, a prose reread, a green build, or a broad test suite alone cannot satisfy it.

## Stop When Done

When the user asks a bounded question, review, or change and that requested outcome is complete, give the final answer immediately. Do not extend the task with optional improvements, audits, upgrades, or adjacent implementation merely because work could continue. Continuation applies only to explicit multi-step implementation work that remains within the requested scope.

When implementation finishes, do not call the goal complete yet. Announce `Implementation complete; goal review started; goal remains ACTIVE` (localized for the user), create the completion checklist, and perform the literal and regression reviews. If review finds a task-caused gap or regression, fix it and repeat the affected review. If the review passes, say the goal is complete and stop. A trailing question such as "anything missing?", "want anything else?", or "is the goal complete?" is forbidden because it reopens a proven bounded goal.

If the user previously declared an unspecified before-finish item, the review cannot pass. Ask specifically for that item while the goal remains `ACTIVE`; do not silently cancel, close, or treat the vague commitment as satisfied. Completion Audit must show that every such commitment was clarified and resolved. Only unsolicited questions after proven completion are forbidden.

Do not repeat the same safety, deletion, cleanup, or progress status message across assistant updates. If a bounded request has no remaining in-scope action, replace "continuing" language with a final answer that states the verified outcome once. Repeated status phrasing is a control-flow failure; stop, summarize the evidence, and close when `FINAL_ALLOWED` is true.

When `GoalStatus` is `ACTIVE`, do not emit a final answer saying the work is incomplete, no result exists, work remains, or execution will continue later. Send a concise commentary progress update and continue execution in the same goal run. Before any final answer on a goal task, read current goal status and reject finalization unless `FINAL_ALLOWED` is true.
- A known regression blocks claiming completion or release. It does not block working on the fix unless continuing would worsen or destroy user data.
- Do not substitute a status message such as "not ready to release" for implementation work the user requested.

## User-Facing Behavior

State progress and evidence, then continue. If a release is not ready, say what remains for release while still completing the requested code path.

## Long Goal Progress Reporting

For a long-running user goal, status updates must be useful progress reports, not heartbeat messages.

- Give a concise progress update after each material milestone, long verification step, scope change, or meaningful blocker analysis.
- Every update must restate the agent's current understanding of the requested outcome so the user can correct drift immediately.
- Report two independent percentages: `Current-step percent` measures only the named step being worked now; `Overall percent` is a conservative estimate against the full current goal and plan. Never present one as a substitute for the other.
- Name the current phase and current step, state the current action, latest concrete evidence, and next gate. The user must be able to tell what the agent understood, what it is doing now, and what happens next without reading earlier updates.
- Do not send a progress update if no new evidence, completed step, failed check, or changed plan exists since the previous update.
- Do not imply completion from percentage alone. Final completion still requires the requested outcome, required gates, and recorded verification.
- Use conservative estimates: discovery and planning should not exceed 30%, implementation should not exceed 75% before relevant validation, and validation/release should not exceed 95% until final gates pass.
- If the goal changes scope, recalculate progress against the new scope and say that the estimate changed because the scope changed.
- A routed update also reports its relation, target step, plan order, and whether the overall estimate changed. Queued future work changes the full-goal denominator but does not falsely reset or inflate current-step progress.

Recommended compact format:

```text
Understanding: <current interpretation of the requested outcome>
Phase: <discovery/planning/implementation/validation/release>
Current step: <named step> — <0..100>%
Overall progress: <conservative 0..95>%
New evidence: <new completed or observed evidence>
Current action: <work happening now>
Next gate: <next required verification or decision>
```

For active goals, `Overall progress` cannot reach 100%. A current step may reach 100% while the overall goal remains active, but the update must then name the next current action. Validate structured progress updates with `scripts/validate-goal-lifecycle.ps1 -ProgressUpdate`; a missing understanding, phase, current-step name, current-step percentage, overall percentage, new evidence, current action, or next gate is invalid.
