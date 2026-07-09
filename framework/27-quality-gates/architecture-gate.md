# Architecture Gate

## Purpose
This gate defines the minimum evidence required before work can be reported as complete. It is intended for AI coding assistants, maintainers, reviewers, and release owners.

## Checks
- The relevant source, configuration, documentation, and runtime paths were inspected.
- Requirements and acceptance criteria are explicit and testable.
- The implementation follows local project patterns and avoids unrelated rewrites.
- Security, performance, reliability, accessibility, and maintainability impacts are reviewed.
- Automated validation was run where available, and manual review covered the remaining risky behavior.
- The final report distinguishes verified facts from assumptions and limitations.

## Failure Conditions
- Empty files, placeholders, shallow outlines, or TODO-only artifacts.
- Claims of completion without validation evidence.
- Unreviewed public API, database, authentication, authorization, deployment, or UX changes.
- Duplicated implementation paths where a shared local pattern already exists.
- Missing rollback or mitigation plan for risky production changes.

## Pass Criteria
- All required files and implementation changes are present.
- The work satisfies the user request without touching unrelated repositories or secrets.
- Validation commands pass, or any unavailable checks are documented with a concrete reason.
- Remaining risks are minor, visible, and paired with practical follow-up steps.

## Evidence Required
- Files changed or reviewed.
- Commands run and pass/fail results.
- Screenshots or rendered artifacts for UI and document work when visual quality matters.
- Link or commit reference when the change is pushed.

## Related Scorecard
Use the matching scorecard in ramework/28-scorecards/ to grade depth and consistency after this gate passes.

## Related Checklist
Use the relevant checklist pack before final response, especially for security, performance, production, testing, and documentation work.
