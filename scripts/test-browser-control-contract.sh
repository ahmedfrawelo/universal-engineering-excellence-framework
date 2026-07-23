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

for term in 'current window size' 'monitor placement' 'zoom' 'tab order' 'active tab' 'Do not call resize' 'Record the initial and final window state'; do
  grep -Fq "$term" "$ROOT/framework/51-browser-session-control/10-window-state-preservation.md" || { echo "Missing window-geometry preservation term: $term" >&2; exit 1; }
done

! grep -Fq 'Isolated contexts are acceptable' "$ROOT/framework/51-browser-session-control/03-no-isolated-browser-by-default.md" || { echo 'Isolated Chrome fallback remains' >&2; exit 1; }
! grep -Fq 'Explicit consent recorded if an isolated fallback was necessary' "$ROOT/framework/29-checklists/32-browser-session-control-checklist.md" || { echo 'Consent-based isolated fallback remains' >&2; exit 1; }
grep -Fq 'only when the user explicitly asks for browser/site/visual work' "$LOADER" || { echo 'Browser selection is not explicit and proportional' >&2; exit 1; }
grep -Fq 'mere mention of a browser' "$LOADER" || { echo 'Casual browser mentions can still trigger browser control' >&2; exit 1; }
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
for term in 'THREAD_CONTROL_CHANNEL_DEGRADED' 'CHROME_EXTERNALLY_UNAVAILABLE' 'VERIFIED_HANDOFF' 'trusted coordinator' 'existing user-owned tab' 'current code state'; do
  grep -Fq "$term" "$ROOT/framework/51-browser-session-control/12-cross-session-evidence-handoff.md" || { echo "Missing evidence-handoff term: $term" >&2; exit 1; }
done
for term in 'first local bridge failure' 'Do not expose attempt counts' 'Browser verification is being completed on your existing tab; implementation continues.'; do
  grep -Fq "$term" "$ROOT/framework/51-browser-session-control/13-user-facing-recovery-protocol.md" || { echo "Missing user-facing recovery term: $term" >&2; exit 1; }
done
for term in 'already part of another browser session' 'Do not ask the user to Share, Connect, restart Chrome, open another tab, or wait for another task' 'repair-chrome-tab-ownership.ps1' 'user.openTabs()' 'exact returned target object' 'claimTab()' 'one automated recovery' 'without a coordinator or user action'; do
  grep -Fq "$term" "$ROOT/framework/51-browser-session-control/14-automatic-tab-ownership-recovery.md" || { echo "Missing automatic ownership-recovery term: $term" >&2; exit 1; }
done

for term in 'connector-created Chrome window' 'repair-chrome-tab-ownership.ps1' 'VERIFIED_HANDOFF' 'non-visual tests can continue' 'keep visual verification explicitly pending'; do
  grep -Fq "$term" "$ROOT/UEEF-LOADER.md" || { echo "Missing loader browser-continuation term: $term" >&2; exit 1; }
done

for file in "$ROOT/UEEF-LOADER.md" "$ROOT/scripts/sync-runtime.ps1" "$ROOT/framework/51-browser-session-control/00-browser-session-first.md"; do
  for term in 'HARD FAIL BEFORE ANY BROWSER TOOL' 'get-ueef-task-preflight.ps1' 'browserGate' 'do not select a browser tool' 'mcp__node_repl__js' 'claimTab()' 'tab.playwright'; do
    grep -Fq "$term" "$file" || { echo "Missing mandatory pre-tool browser gate term $term in $file" >&2; exit 1; }
  done
done
for term in "status = 'REQUIRED'" "enforcement = 'HARD_FAIL_BEFORE_BROWSER_TOOL'" 'requiredBeforeTool' 'allowedPath' 'forbiddenSurfaces' 'Do not select or call a browser tool'; do
  grep -Fq "$term" "$ROOT/scripts/get-ueef-task-preflight.ps1" || { echo "Missing structured browser preflight gate term: $term" >&2; exit 1; }
done

for file in "$ROOT/QUICK_START.md" "$ROOT/INSTALL.md"; do
  for term in 'sync-runtime' 'still opens or proposes another browser' 'immediately'; do
    grep -Fq "$term" "$file" || { echo "Missing browser runtime-sync guidance $term in $file" >&2; exit 1; }
  done
done

for term in 'same user-owned tab' 'Automatic Failover' 'VERIFIED_HANDOFF' 'visible Windows control' 'never creates' 'No user acknowledgement'; do
  grep -Fq "$term" "$ROOT/framework/51-browser-session-control/16-control-channel-failover.md" || { echo "Missing control-channel failover term: $term" >&2; exit 1; }
done

if grep -Eiq 'wait for the user to say|ask the user to say|say [`'"'"']?تم' "$ROOT"/framework/51-browser-session-control/*.md; then
  echo 'Manual user-confirmation browser handoff remains' >&2
  exit 1
fi

readiness="$ROOT/framework/51-browser-session-control/15-chrome-control-readiness.md"
previous=0
for term in 'browser-client.mjs' 'claimTab()' 'repair-chrome-tab-ownership.ps1' 'VERIFIED_HANDOFF'; do
  line=$(grep -nF "$term" "$readiness" | head -n 1 | cut -d: -f1)
  [ -n "$line" ] && [ "$line" -gt "$previous" ] || { echo "Browser recovery term missing or out of order: $term" >&2; exit 1; }
  previous=$line
done

printf '%s\n' 'Browser control contract tests passed'
