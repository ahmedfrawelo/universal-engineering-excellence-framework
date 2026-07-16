#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
v="$ROOT/scripts/validate-goal-lifecycle.sh"
if "$v" --goal-status ACTIVE --terminal-final >/dev/null 2>&1; then echo 'ACTIVE terminal final accepted' >&2; exit 1; fi
if "$v" --goal-status COMPLETE --terminal-final --required-work-remaining >/dev/null 2>&1; then echo 'Invalid COMPLETE accepted' >&2; exit 1; fi
if "$v" --goal-status BLOCKED --terminal-final >/dev/null 2>&1; then echo 'Invalid BLOCKED accepted' >&2; exit 1; fi
if "$v" --goal-status COMPLETE --terminal-final --outcome-satisfied --gates-pass-or-accepted --verification-recorded --browser-verification-required >/dev/null 2>&1; then echo 'COMPLETE accepted without browser verification' >&2; exit 1; fi
if "$v" --goal-status COMPLETE --terminal-final --outcome-satisfied --gates-pass-or-accepted --verification-recorded --visual-verification-required >/dev/null 2>&1; then echo 'COMPLETE accepted without visual verification' >&2; exit 1; fi
if "$v" --goal-status BLOCKED --terminal-final --external-blocker --no-meaningful-local-work --external-state-change-required --thread-control-channel-degraded >/dev/null 2>&1; then echo 'BLOCKED accepted for thread-local control degradation' >&2; exit 1; fi
if "$v" --goal-status ACTIVE --browser-verification-required --verified-browser-evidence-handoff >/dev/null 2>&1; then echo 'Stale handoff accepted' >&2; exit 1; fi
if "$v" --goal-status ACTIVE --user-restart-chrome-requested >/dev/null 2>&1; then echo 'Restart request accepted without external Chrome evidence' >&2; exit 1; fi
if "$v" --goal-status ACTIVE --thread-control-channel-degraded --user-facing-status 'Browser bridge failed three times.' >/dev/null 2>&1; then echo 'Retry-count status accepted' >&2; exit 1; fi
if "$v" --goal-status ACTIVE --thread-control-channel-degraded --user-facing-status 'Stopped visual verification.' >/dev/null 2>&1; then echo 'Stopped-verification status accepted' >&2; exit 1; fi
if "$v" --goal-status BLOCKED --terminal-final --external-blocker --no-meaningful-local-work --external-state-change-required --pending-screenshot-evidence >/dev/null 2>&1; then echo 'BLOCKED accepted for pending screenshot evidence' >&2; exit 1; fi
"$v" --goal-status ACTIVE >/dev/null
"$v" --goal-status ACTIVE --terminal-final --status-only >/dev/null
"$v" --goal-status COMPLETE --terminal-final --outcome-satisfied --gates-pass-or-accepted --verification-recorded >/dev/null
"$v" --goal-status COMPLETE --terminal-final --outcome-satisfied --gates-pass-or-accepted --verification-recorded --browser-verification-required --browser-verification-passed --visual-verification-required --visual-verification-passed >/dev/null
"$v" --goal-status COMPLETE --terminal-final --outcome-satisfied --gates-pass-or-accepted --verification-recorded --browser-verification-required --visual-verification-required --verified-browser-evidence-handoff --handoff-matches-current-code-state --thread-control-channel-degraded >/dev/null
"$v" --goal-status ACTIVE --thread-control-channel-degraded --user-facing-status 'Browser verification is being completed on your existing tab; implementation continues.' >/dev/null
"$v" --goal-status ACTIVE --pending-screenshot-evidence >/dev/null
"$v" --goal-status BLOCKED --terminal-final --external-blocker --no-meaningful-local-work --external-state-change-required >/dev/null
echo 'Unix goal lifecycle tests passed'
