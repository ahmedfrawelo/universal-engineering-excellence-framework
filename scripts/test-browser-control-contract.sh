#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
POLICY="$ROOT/framework/51-browser-session-control/11-control-surface-selection.md"
LOADER="$ROOT/framework/01-core/01-master-loader.md"
GATE="$ROOT/framework/27-quality-gates/23-browser-session-control-gate.md"
RECOVERY="$ROOT/framework/51-browser-session-control/09-platform-authorized-chrome-control.md"

for term in 'mcp__node_repl__js' 'mcp__playwright__*' 'mcp__chrome_devtools__*' 'tab.playwright' 'user.openTabs()' 'claimTab()'; do
  grep -Fq "$term" "$POLICY" "$LOADER" "$GATE" || { echo "Missing browser contract term: $term" >&2; exit 1; }
done

! grep -Fq 'Isolated contexts are acceptable' "$ROOT/framework/51-browser-session-control/03-no-isolated-browser-by-default.md" || { echo 'Isolated Chrome fallback remains' >&2; exit 1; }
! grep -Fq 'Explicit consent recorded if an isolated fallback was necessary' "$ROOT/framework/29-checklists/32-browser-session-control-checklist.md" || { echo 'Consent-based isolated fallback remains' >&2; exit 1; }
grep -Fq 'Load modules `00`, `01`, `02`, `03`' "$LOADER" || { echo 'No-isolated-browser module is not selected' >&2; exit 1; }
grep -Fq '`15`' "$LOADER" || { echo 'Chrome readiness module is not selected' >&2; exit 1; }
for term in 'bootstrap-troubleshooting' 'chrome-troubleshooting' 'Do not invent a `file:///` variant' 'keep the task active'; do
  grep -Fq "$term" "$RECOVERY" || { echo "Missing Chrome bridge recovery term: $term" >&2; exit 1; }
done
for term in 'Chrome readiness flow' 'browser-client.mjs' 'user.openTabs()' 'claimTab()' 'THREAD_CONTROL_CHANNEL_DEGRADED' 'CHROME_EXTERNALLY_UNAVAILABLE' 'VERIFIED_HANDOFF' 'chrome.tabs.finalize(...)' 'not enough to prove that Chrome cannot be used' 'cannot become a false `BLOCKED` state'; do
  grep -Fq "$term" "$ROOT/framework/51-browser-session-control/15-chrome-control-readiness.md" || { echo "Missing Chrome readiness term: $term" >&2; exit 1; }
done
grep -Fq 'Chrome readiness flow completed:' "$ROOT/framework/03-runtime/00-runtime-sequence.md" || { echo 'Missing runtime Chrome readiness field' >&2; exit 1; }
grep -Fq 'Automatic ownership repair run when needed:' "$ROOT/framework/03-runtime/00-runtime-sequence.md" || { echo 'Missing runtime ownership-repair field' >&2; exit 1; }
grep -Fq 'do not report `COMPLETE`' "$ROOT/framework/51-browser-session-control/07-browser-task-verification.md" || { echo 'Missing required-visual completion guard' >&2; exit 1; }
grep -Fq 'chrome.tabs.finalize(...)' "$ROOT/framework/51-browser-session-control/07-browser-task-verification.md" || { echo 'Missing stale-tab ownership cleanup rule' >&2; exit 1; }
for term in 'THREAD_CONTROL_CHANNEL_DEGRADED' 'CHROME_EXTERNALLY_UNAVAILABLE' 'VERIFIED_HANDOFF' 'current code state'; do
  grep -Fq "$term" "$ROOT/framework/51-browser-session-control/12-cross-session-evidence-handoff.md" || { echo "Missing evidence-handoff term: $term" >&2; exit 1; }
done
for term in 'first local bridge failure' 'Do not expose attempt counts' 'Browser verification is being completed on your existing tab; implementation continues.'; do
  grep -Fq "$term" "$ROOT/framework/51-browser-session-control/13-user-facing-recovery-protocol.md" || { echo "Missing user-facing recovery term: $term" >&2; exit 1; }
done
for term in 'already part of another browser session' 'repair-chrome-tab-ownership.ps1' 'without a coordinator or user action'; do
  grep -Fq "$term" "$ROOT/framework/51-browser-session-control/14-automatic-tab-ownership-recovery.md" || { echo "Missing automatic ownership-recovery term: $term" >&2; exit 1; }
done

printf '%s\n' 'Browser control contract tests passed'
