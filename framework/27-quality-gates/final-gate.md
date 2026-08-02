# Final Gate

## Purpose
This gate defines the minimum evidence required before work can be reported as complete. It is intended for AI coding assistants, maintainers, reviewers, and release owners.

## Checks
- The relevant source, configuration, documentation, and runtime paths were inspected.
- Requirements and acceptance criteria are explicit and testable.
- The implementation follows local project patterns and avoids unrelated rewrites.
- Security, performance, reliability, accessibility, and maintainability impacts are reviewed.
- Automated validation was run where available, and manual review covered the remaining risky behavior.
- The final report distinguishes verified facts from assumptions and limitations.
- The final report answers the user's direct question first and does not bury the outcome behind internal process detail.
- Multi-step active-goal milestone updates expose the current understanding, named current step, current-step percent, conservative overall percent, new evidence, current action, and next gate as separate fields.
- Completion, perfection, release, browser verification, push, and runtime activation claims are backed by current evidence.
- `scripts/validate-completion-audit.ps1` passes a schema-version-2 artifact whose verbatim source review covers every non-whitespace character of the original goal and links every reviewed segment to a requirement; `remainingWork` and `knownProblems` are empty.
- The audit proves implementation completion was announced before goal review, the goal remained active during review, every requirement checklist item passed both requested-implementation and best-feasible-outcome review, and every changed surface has a passing regression check.
- Every requirement is compared to actual implemented and observed behavior with current evidence, and every implementation inventory item traces back to a requirement; no untraced implementation remains.
- Every received goal update is detected and classified; no missing implementation, pending update, or open resume point remains.
- No task-caused regression remains. Unrelated findings are documented with evidence and an out-of-scope reason and were not repaired without scope authority.
- Every explicit before-finish user commitment was clarified before completion and has resolution evidence; no pending commitment remains.

## Failure Conditions
- A terminal final response while `GoalStatus` is `ACTIVE`, unless the user explicitly requested status-only reporting.
- `GoalStatus: COMPLETE` while required work, acceptance criteria, tests, or verification remain.
- `GoalStatus: BLOCKED` for an internal implementation failure or while meaningful local work remains.
- Empty files, placeholders, shallow outlines, or TODO-only artifacts.
- Claims of completion without validation evidence.
- A `COMPLETE` transition without a passing completion-audit artifact, or with any known problem or required work still recorded.
- Overstated final wording such as "perfect", "100%", "fully verified", or "released" without evidence for every explicit requirement.
- Asking whether more work is wanted, whether anything is missing, or whether the goal is complete after the completion audit already proved the bounded goal complete.
- Unreviewed public API, database, authentication, authorization, deployment, or UX changes.
- Duplicated implementation paths where a shared local pattern already exists.
- Missing rollback or mitigation plan for risky production changes.

## Pass Criteria
- Goal lifecycle transition satisfies `FINAL_ALLOWED` and `COMPLETE_ALLOWED` from the delivery continuation contract.
- All required files and implementation changes are present.
- The work satisfies the user request without touching unrelated repositories or secrets.
- The final scope does not include unrelated fixes, unrelated rewrites, or unrelated error chasing unless the user explicitly requested broad cleanup or those issues directly blocked validation.
- Validation commands pass, or non-required unavailable checks are documented with a concrete reason. Explicitly required browser or visual verification cannot be waived by documenting unavailability and blocks `GoalStatus: COMPLETE` until it passes.
- Remaining risks are minor, visible, and paired with practical follow-up steps.

## Evidence Required
- Files changed or reviewed.
- Commands run and pass/fail results.
- Screenshots or rendered artifacts for UI and document work when visual quality matters.
- Link or commit reference when the change is pushed.
- For T2+ work, the task evidence artifact declares every applicable gate and domain; validation of the final domain also validates every other declared domain rather than accepting a summary-only PASS.

## Related Scorecard
Use the matching scorecard in framework/28-scorecards/ to grade depth and consistency after this gate passes.

## Related Checklist
Use the relevant checklist pack before final response, especially for security, performance, production, testing, and documentation work.
