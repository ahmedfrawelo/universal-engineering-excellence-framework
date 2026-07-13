#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
POLICY="$ROOT/framework/51-browser-session-control/11-control-surface-selection.md"
LOADER="$ROOT/framework/01-core/01-master-loader.md"
GATE="$ROOT/framework/27-quality-gates/23-browser-session-control-gate.md"

for term in 'mcp__node_repl__js' 'mcp__playwright__*' 'mcp__chrome_devtools__*' 'tab.playwright' 'user.openTabs()' 'claimTab()'; do
  grep -Fq "$term" "$POLICY" "$LOADER" "$GATE" || { echo "Missing browser contract term: $term" >&2; exit 1; }
done

! grep -Fq 'Isolated contexts are acceptable' "$ROOT/framework/51-browser-session-control/03-no-isolated-browser-by-default.md" || { echo 'Isolated Chrome fallback remains' >&2; exit 1; }
! grep -Fq 'Explicit consent recorded if an isolated fallback was necessary' "$ROOT/framework/29-checklists/32-browser-session-control-checklist.md" || { echo 'Consent-based isolated fallback remains' >&2; exit 1; }
grep -Fq 'Load modules `00`, `01`, `02`, `03`' "$LOADER" || { echo 'No-isolated-browser module is not selected' >&2; exit 1; }

printf '%s\n' 'Browser control contract tests passed'
