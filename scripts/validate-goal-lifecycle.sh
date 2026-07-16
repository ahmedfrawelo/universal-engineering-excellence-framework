#!/usr/bin/env sh
set -eu
status=ACTIVE; terminal=false; status_only=false; external=false; no_work=false; state_change=false; outcome=false; remaining=false; gates=false; verified=false; browser_required=false; browser_passed=false; visual_required=false; visual_passed=false; thread_degraded=false; handoff=false; handoff_current=false; chrome_unavailable=false; restart_requested=false; pending_screenshot=false; user_facing_status=''
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
    --verified-browser-evidence-handoff) handoff=true; shift ;;
    --handoff-matches-current-code-state) handoff_current=true; shift ;;
    --chrome-externally-unavailable) chrome_unavailable=true; shift ;;
    --user-restart-chrome-requested) restart_requested=true; shift ;;
    --pending-screenshot-evidence) pending_screenshot=true; shift ;;
    --user-facing-status) user_facing_status=$2; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
blocked=false; complete=false; allowed=false; browser_allowed=false; visual_allowed=false; handoff_allowed=false
[ "$handoff" = true ] && [ "$handoff_current" = true ] && handoff_allowed=true
{ [ "$browser_required" = false ] || [ "$browser_passed" = true ] || [ "$handoff_allowed" = true ]; } && browser_allowed=true
{ [ "$visual_required" = false ] || [ "$visual_passed" = true ] || [ "$handoff_allowed" = true ]; } && visual_allowed=true
[ "$status" = BLOCKED ] && [ "$external" = true ] && [ "$no_work" = true ] && [ "$state_change" = true ] && blocked=true
[ "$status" = COMPLETE ] && [ "$outcome" = true ] && [ "$remaining" = false ] && [ "$gates" = true ] && [ "$verified" = true ] && [ "$browser_allowed" = true ] && [ "$visual_allowed" = true ] && complete=true
if [ "$status_only" = true ] || [ "$blocked" = true ] || [ "$complete" = true ]; then allowed=true; fi
[ "$status" != BLOCKED ] || [ "$blocked" = true ] || { echo 'Invalid BLOCKED transition.' >&2; exit 1; }
[ "$status" != BLOCKED ] || [ "$thread_degraded" = false ] || [ "$chrome_unavailable" = true ] || { echo 'Thread-local browser control degradation is not a valid BLOCKED transition.' >&2; exit 1; }
[ "$status" != BLOCKED ] || [ "$pending_screenshot" = false ] || { echo 'Pending screenshot evidence is not a valid BLOCKED transition.' >&2; exit 1; }
[ "$restart_requested" = false ] || [ "$chrome_unavailable" = true ] || { echo 'A Chrome restart request requires independent Chrome unavailability evidence.' >&2; exit 1; }
[ "$thread_degraded" = false ] || [ "$chrome_unavailable" = true ] || [ -z "$user_facing_status" ] || [ "$user_facing_status" = 'Browser verification is being completed on your existing tab; implementation continues.' ] || { echo 'Thread-local browser degradation requires the canonical user-facing recovery status.' >&2; exit 1; }
{ [ "$browser_required" = false ] && [ "$visual_required" = false ]; } || [ "$handoff" = false ] || [ "$handoff_current" = true ] || { echo 'Browser evidence handoff does not cover the current code state.' >&2; exit 1; }
[ "$status" != COMPLETE ] || [ "$complete" = true ] || { echo 'Invalid COMPLETE transition.' >&2; exit 1; }
[ "$terminal" = false ] || [ "$allowed" = true ] || { echo 'Terminal final response is forbidden for this goal state.' >&2; exit 1; }
printf 'GoalStatus=%s TerminalFinalAllowed=%s BlockedAllowed=%s CompleteAllowed=%s\n' "$status" "$allowed" "$blocked" "$complete"
