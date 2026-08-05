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

If the selected model reports `Selected model is at capacity`, attempt the single declared fallback from `config/model-routing-policy.json`. Record the primary capacity result and the model/effort actually used. Do not rotate accounts, cookies, profiles, or credentials. If both named routes are unavailable, keep the task active and report provider capacity; do not silently fall back to the primary conversation's model. For T4, record that independent verification could not be delegated and strengthen direct evidence. Do not pretend delegation occurred.

If an agent fails, retry once only when the failure is transient and the task remains valid. Otherwise reclaim the work or escalate. Never loop agents on the same unresolved prompt.

## Verification

- T0: direct outcome check.
- T1: focused command, test, or inspection.
- T2: focused tests plus integration review.
- T3: broader regression gates and explicit risk review.
- T3: broader regression gates, explicit risk review, and fresh-context review when the route marks it consequential.
- T4: independent verification, a passing fresh-context review artifact when an eligible lane is available, rollback evidence where applicable, and release or production proof.

Use `scripts/validate-fresh-review-evidence.ps1` for a recorded review. A capability gap may explain why a fresh reviewer could not run, but it cannot be relabeled as independent verification.

The final status reports the route and evidence, not internal chain-of-thought or unnecessary agent transcripts.
