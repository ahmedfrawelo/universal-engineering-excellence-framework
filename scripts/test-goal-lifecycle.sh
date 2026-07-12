#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
v="$ROOT/scripts/validate-goal-lifecycle.sh"
if "$v" --goal-status ACTIVE --terminal-final >/dev/null 2>&1; then echo 'ACTIVE terminal final accepted' >&2; exit 1; fi
if "$v" --goal-status COMPLETE --terminal-final --required-work-remaining >/dev/null 2>&1; then echo 'Invalid COMPLETE accepted' >&2; exit 1; fi
if "$v" --goal-status BLOCKED --terminal-final >/dev/null 2>&1; then echo 'Invalid BLOCKED accepted' >&2; exit 1; fi
"$v" --goal-status ACTIVE >/dev/null
"$v" --goal-status ACTIVE --terminal-final --status-only >/dev/null
"$v" --goal-status COMPLETE --terminal-final --outcome-satisfied --gates-pass-or-accepted --verification-recorded >/dev/null
"$v" --goal-status BLOCKED --terminal-final --external-blocker --no-meaningful-local-work --external-state-change-required >/dev/null
echo 'Unix goal lifecycle tests passed'
