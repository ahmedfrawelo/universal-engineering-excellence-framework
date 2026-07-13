#!/usr/bin/env sh
set -eu
status=ACTIVE; terminal=false; status_only=false; external=false; no_work=false; state_change=false; outcome=false; remaining=false; gates=false; verified=false; browser_required=false; browser_passed=false; visual_required=false; visual_passed=false
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
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
blocked=false; complete=false; allowed=false; browser_allowed=false; visual_allowed=false
[ "$browser_required" = false ] || [ "$browser_passed" = true ] && browser_allowed=true
[ "$visual_required" = false ] || [ "$visual_passed" = true ] && visual_allowed=true
[ "$status" = BLOCKED ] && [ "$external" = true ] && [ "$no_work" = true ] && [ "$state_change" = true ] && blocked=true
[ "$status" = COMPLETE ] && [ "$outcome" = true ] && [ "$remaining" = false ] && [ "$gates" = true ] && [ "$verified" = true ] && [ "$browser_allowed" = true ] && [ "$visual_allowed" = true ] && complete=true
if [ "$status_only" = true ] || [ "$blocked" = true ] || [ "$complete" = true ]; then allowed=true; fi
[ "$status" != BLOCKED ] || [ "$blocked" = true ] || { echo 'Invalid BLOCKED transition.' >&2; exit 1; }
[ "$status" != COMPLETE ] || [ "$complete" = true ] || { echo 'Invalid COMPLETE transition.' >&2; exit 1; }
[ "$terminal" = false ] || [ "$allowed" = true ] || { echo 'Terminal final response is forbidden for this goal state.' >&2; exit 1; }
printf 'GoalStatus=%s TerminalFinalAllowed=%s BlockedAllowed=%s CompleteAllowed=%s\n' "$status" "$allowed" "$blocked" "$complete"
