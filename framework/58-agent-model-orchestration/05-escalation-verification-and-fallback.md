# Escalation, Verification, and Fallback

## Escalation Triggers

Increase tier, model class, reasoning, or verification when:

- discovered files or systems exceed the original scope;
- requirements conflict or architecture ownership is unclear;
- tests fail for an unexplained reason;
- a child reports low confidence or incomplete evidence;
- security, production, privacy, migration, or data-loss risk appears;
- integration creates cross-agent conflicts.

## Fallback

If subagents or model overrides are unavailable, the lead performs the work with the strongest available model and the same quality gates. Record the capability limitation; do not pretend delegation occurred.

If an agent fails, retry once only when the failure is transient and the task remains valid. Otherwise reclaim the work or escalate. Never loop agents on the same unresolved prompt.

## Verification

- T0: direct outcome check.
- T1: focused command, test, or inspection.
- T2: focused tests plus integration review.
- T3: broader regression gates and explicit risk review.
- T4: independent verification, rollback evidence where applicable, and release or production proof.

The final status reports the route and evidence, not internal chain-of-thought or unnecessary agent transcripts.
