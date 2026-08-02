#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
status=ACTIVE; terminal=false; status_only=false; external=false; no_work=false; state_change=false; outcome=false; remaining=false; gates=false; verified=false; browser_required=false; browser_passed=false; visual_required=false; visual_passed=false; thread_degraded=false; handoff=false; handoff_current=false; chrome_unavailable=false; restart_requested=false; pending_screenshot=false; user_facing_status=''; completion_audit=''; browser_failure_stage=''; browser_failure_reason=''; browser_failure_next=''; progress_update=false; progress_percent=-1; progress_step_percent=-1; progress_phase=unknown; progress_understanding=''; progress_current_step=''; progress_evidence=''; progress_current_action=''; progress_next_gate=''; implementation_complete=false; goal_review_started=false; goal_review_checklist=false; task_regression_review=false; post_completion_question=false; before_finish_pending=false; before_finish_asked=false; goal_update=false; update_route=UNKNOWN; update_summary=''; update_reason=''; update_acceptance=''; update_plan=false; resume_point=false; current_preserved=false; current_paused=false; current_integrated=false; prior_reopened=false; prior_verified=false; resume_restored=false; future_queued=false; future_order=-1; future_dependencies=''; replan=false; update_clarification=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --goal-status) status=$2; shift 2 ;;
    --terminal-final) terminal=true; shift ;;
    --status-only) status_only=true; shift ;;
    --external-blocker) external=true; shift ;;
    --no-meaningful-local-work) no_work=true; shift ;;
    --external-state-change-required) state_change=true; shift ;;
    --outcome-satisfied) outcome=true; shift ;;
    --required-work-remaining) remaining=true; shift ;;
    --gates-pass-or-accepted) gates=true; shift ;;
    --verification-recorded) verified=true; shift ;;
    --browser-verification-required) browser_required=true; shift ;;
    --browser-verification-passed) browser_passed=true; shift ;;
    --visual-verification-required) visual_required=true; shift ;;
    --visual-verification-passed) visual_passed=true; shift ;;
    --thread-control-channel-degraded) thread_degraded=true; shift ;;
    --browser-failure-stage) browser_failure_stage=$2; shift 2 ;;
    --browser-failure-reason) browser_failure_reason=$2; shift 2 ;;
    --browser-failure-next) browser_failure_next=$2; shift 2 ;;
    --verified-browser-evidence-handoff) handoff=true; shift ;;
    --handoff-matches-current-code-state) handoff_current=true; shift ;;
    --chrome-externally-unavailable) chrome_unavailable=true; shift ;;
    --user-restart-chrome-requested) restart_requested=true; shift ;;
    --pending-screenshot-evidence) pending_screenshot=true; shift ;;
    --implementation-complete) implementation_complete=true; shift ;;
    --goal-review-started) goal_review_started=true; shift ;;
    --goal-review-checklist-created) goal_review_checklist=true; shift ;;
    --task-regression-review-started) task_regression_review=true; shift ;;
    --post-completion-question-asked) post_completion_question=true; shift ;;
    --user-before-finish-commitment-pending) before_finish_pending=true; shift ;;
    --before-finish-clarification-asked) before_finish_asked=true; shift ;;
    --goal-update-received) goal_update=true; shift ;;
    --goal-update-route) update_route=$2; shift 2 ;;
    --goal-update-summary) update_summary=$2; shift 2 ;;
    --goal-update-impact-reason) update_reason=$2; shift 2 ;;
    --goal-update-acceptance-criteria) update_acceptance=$2; shift 2 ;;
    --goal-update-plan-updated) update_plan=true; shift ;;
    --resume-point-recorded) resume_point=true; shift ;;
    --current-step-preserved) current_preserved=true; shift ;;
    --current-step-paused) current_paused=true; shift ;;
    --current-step-update-integrated) current_integrated=true; shift ;;
    --prior-step-reopened) prior_reopened=true; shift ;;
    --prior-step-update-verified) prior_verified=true; shift ;;
    --resume-point-restored) resume_restored=true; shift ;;
    --future-step-queued) future_queued=true; shift ;;
    --future-step-order) future_order=$2; shift 2 ;;
    --future-step-dependencies) future_dependencies=$2; shift 2 ;;
    --replan-completed) replan=true; shift ;;
    --goal-update-clarification-asked) update_clarification=true; shift ;;
    --user-facing-status) user_facing_status=$2; shift 2 ;;
    --completion-audit) completion_audit=$2; shift 2 ;;
    --progress-update) progress_update=true; shift ;;
    --progress-percent) progress_percent=$2; shift 2 ;;
    --progress-current-step-percent) progress_step_percent=$2; shift 2 ;;
    --progress-phase) progress_phase=$2; shift 2 ;;
    --progress-understanding) progress_understanding=$2; shift 2 ;;
    --progress-current-step) progress_current_step=$2; shift 2 ;;
    --progress-evidence) progress_evidence=$2; shift 2 ;;
    --progress-current-action) progress_current_action=$2; shift 2 ;;
    --progress-next-gate) progress_next_gate=$2; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
case "$status" in ACTIVE|BLOCKED|COMPLETE) ;; *) echo 'Invalid goal status.' >&2; exit 2;; esac
case "$progress_phase" in discovery|planning|implementation|validation|release|complete|unknown) ;; *) echo 'Invalid progress phase.' >&2; exit 2;; esac
blocked=false; complete=false; allowed=false; browser_allowed=false; visual_allowed=false; handoff_allowed=false; completion_audit_passed=false
user_input_wait=false
if [ -n "$completion_audit" ] && [ -f "$completion_audit" ] && [ -f "$ROOT/scripts/validate-completion-audit.sh" ] && sh "$ROOT/scripts/validate-completion-audit.sh" "$completion_audit" >/dev/null 2>&1; then completion_audit_passed=true; fi
[ "$handoff" = true ] && [ "$handoff_current" = true ] && handoff_allowed=true
{ [ "$browser_required" = false ] || [ "$browser_passed" = true ] || [ "$handoff_allowed" = true ]; } && browser_allowed=true
{ [ "$visual_required" = false ] || [ "$visual_passed" = true ] || [ "$handoff_allowed" = true ]; } && visual_allowed=true
[ "$status" = BLOCKED ] && [ "$external" = true ] && [ "$no_work" = true ] && [ "$state_change" = true ] && blocked=true
[ "$status" = COMPLETE ] && [ "$outcome" = true ] && [ "$remaining" = false ] && [ "$gates" = true ] && [ "$verified" = true ] && [ "$completion_audit_passed" = true ] && [ "$browser_allowed" = true ] && [ "$visual_allowed" = true ] && complete=true
if [ "$status_only" = true ] || [ "$blocked" = true ] || [ "$complete" = true ]; then allowed=true; fi
if [ "$before_finish_pending" = true ] && [ "$status" = ACTIVE ] && [ "$before_finish_asked" = true ]; then user_input_wait=true; allowed=true; fi
if [ "$goal_update" = true ] && [ "$update_route" = CONFLICT_OR_AMBIGUOUS ] && [ "$status" = ACTIVE ] && [ "$update_clarification" = true ] && [ "$resume_point" = true ] && [ "$current_preserved" = true ]; then allowed=true; fi
[ "$status" != BLOCKED ] || [ "$blocked" = true ] || { echo 'Invalid BLOCKED transition.' >&2; exit 1; }
[ "$status" != BLOCKED ] || [ "$browser_required" = false ] || [ "$chrome_unavailable" = true ] || { echo 'Browser verification requirement is not a valid BLOCKED transition without independent Chrome unavailability evidence.' >&2; exit 1; }
[ "$status" != BLOCKED ] || [ "$thread_degraded" = false ] || [ "$chrome_unavailable" = true ] || { echo 'Thread-local browser control degradation is not a valid BLOCKED transition.' >&2; exit 1; }
[ "$status" != BLOCKED ] || [ "$pending_screenshot" = false ] || { echo 'Pending screenshot evidence is not a valid BLOCKED transition.' >&2; exit 1; }
[ "$restart_requested" = false ] || [ "$chrome_unavailable" = true ] || { echo 'A Chrome restart request requires independent Chrome unavailability evidence.' >&2; exit 1; }
if [ "$implementation_complete" = true ]; then [ "$status" = ACTIVE ] && [ "$goal_review_started" = true ] && [ "$goal_review_checklist" = true ] && [ "$task_regression_review" = true ] || { echo 'Implementation completion must transition to goal review with checklist and task-regression review while ACTIVE.' >&2; exit 1; }; fi
[ "$post_completion_question" = false ] || [ "$status" != COMPLETE ] || { echo 'After goal completion, stop without asking for more work.' >&2; exit 1; }
[ "$before_finish_pending" = false ] || [ "$user_input_wait" = true ] || { echo 'A before-finish commitment keeps the goal ACTIVE and requires clarification.' >&2; exit 1; }
if [ "$goal_update" = true ]; then
  [ -n "$update_summary" ] && [ -n "$update_reason" ] && [ -n "$update_acceptance" ] && [ "$update_plan" = true ] && [ "$update_route" != UNKNOWN ] || { echo 'Goal updates require summary, reason, acceptance criteria, explicit route, and updated plan.' >&2; exit 1; }
  case "$update_route" in
    CURRENT_STEP) [ "$current_preserved" = true ] && [ "$current_integrated" = true ] || { echo 'Invalid current-step update route.' >&2; exit 1; } ;;
    PRIOR_STEP_CORRECTION) [ "$resume_point" = true ] && [ "$current_paused" = true ] && [ "$prior_reopened" = true ] && [ "$prior_verified" = true ] && [ "$resume_restored" = true ] || { echo 'Invalid prior-step correction route.' >&2; exit 1; } ;;
    FUTURE_STEP) [ "$current_preserved" = true ] && [ "$future_queued" = true ] && [ "$future_order" -ge 1 ] && [ -n "$future_dependencies" ] || { echo 'Invalid future-step route.' >&2; exit 1; } ;;
    INVALIDATES_CURRENT_WORK) [ "$resume_point" = true ] && [ "$current_paused" = true ] && [ "$replan" = true ] || { echo 'Invalid current-work invalidation route.' >&2; exit 1; } ;;
    CONFLICT_OR_AMBIGUOUS) [ "$status" = ACTIVE ] && [ "$update_clarification" = true ] && [ "$resume_point" = true ] && [ "$current_preserved" = true ] || { echo 'Invalid conflicting update route.' >&2; exit 1; } ;;
    *) echo 'Unknown goal update route.' >&2; exit 1 ;;
  esac
fi
if [ "$thread_degraded" = true ] && [ "$chrome_unavailable" = false ]; then
  [ -n "$browser_failure_stage" ] && [ -n "$browser_failure_reason" ] && [ -n "$browser_failure_next" ] || { echo 'Thread-local browser degradation requires stage, reason, and next action.' >&2; exit 1; }
  browser_failure_reason_lower=$(printf '%s' "$browser_failure_reason" | tr '[:upper:]' '[:lower:]')
  case "$browser_failure_reason_lower" in *password*|*cookie*|*storage*|*token*|*secret*|*stack\ trace*) echo 'Browser failure reason exposes prohibited detail.' >&2; exit 1;; esac
  expected_status="Chrome recovery: stage=$browser_failure_stage; reason=$browser_failure_reason; next=$browser_failure_next. Implementation continues."
  [ "$user_facing_status" = "$expected_status" ] || { echo 'Thread-local browser degradation requires the structured stage/reason/next recovery status.' >&2; exit 1; }
fi
{ [ "$browser_required" = false ] && [ "$visual_required" = false ]; } || [ "$handoff" = false ] || [ "$handoff_current" = true ] || { echo 'Browser evidence handoff does not cover the current code state.' >&2; exit 1; }
case "$progress_percent" in -1|0|[1-9]|[1-9][0-9]|[1-9][0-9][0-9]) ;; *) echo 'Overall progress percentage must be an integer.' >&2; exit 1;; esac
case "$progress_step_percent" in -1|0|[1-9]|[1-9][0-9]|[1-9][0-9][0-9]) ;; *) echo 'Current-step progress percentage must be an integer.' >&2; exit 1;; esac
[ "$progress_percent" -le 100 ] || { echo 'Overall progress percent cannot exceed 100.' >&2; exit 1; }
[ "$progress_step_percent" -le 100 ] || { echo 'Current-step progress percent cannot exceed 100.' >&2; exit 1; }
if [ "$progress_update" = true ]; then
  [ "$progress_percent" -ge 0 ] || { echo 'Progress updates require an explicit conservative overall percentage.' >&2; exit 1; }
  [ "$progress_step_percent" -ge 0 ] || { echo 'Progress updates require an explicit current-step percentage.' >&2; exit 1; }
  [ "$progress_phase" != unknown ] || { echo 'Progress updates require an explicit phase.' >&2; exit 1; }
  [ -n "$progress_understanding" ] && [ -n "$progress_current_step" ] && [ -n "$progress_evidence" ] && [ -n "$progress_current_action" ] && [ -n "$progress_next_gate" ] || { echo 'Progress updates require understanding, current step, new evidence, current action, and next gate.' >&2; exit 1; }
fi
[ "$progress_percent" -ne 100 ] || [ "$status" = COMPLETE ] || { echo 'Overall progress cannot be 100 before the goal is complete.' >&2; exit 1; }
case "$progress_phase" in discovery|planning) [ "$progress_percent" -le 30 ] || { echo 'Discovery or planning progress cannot exceed 30 percent.' >&2; exit 1; };; implementation) [ "$progress_percent" -le 75 ] || { echo 'Implementation progress cannot exceed 75 percent before validation.' >&2; exit 1; };; validation|release) { [ "$progress_percent" -le 95 ] || [ "$status" = COMPLETE ]; } || { echo 'Validation or release progress cannot exceed 95 percent before completion.' >&2; exit 1; };; esac
[ "$status" != COMPLETE ] || [ "$complete" = true ] || { echo 'Invalid COMPLETE transition.' >&2; exit 1; }
[ "$terminal" = false ] || [ "$allowed" = true ] || { echo 'Terminal final response is forbidden for this goal state.' >&2; exit 1; }
printf 'GoalStatus=%s TerminalFinalAllowed=%s BlockedAllowed=%s CompleteAllowed=%s ProgressPercent=%s ProgressCurrentStepPercent=%s ProgressPhase=%s\n' "$status" "$allowed" "$blocked" "$complete" "$progress_percent" "$progress_step_percent" "$progress_phase"
