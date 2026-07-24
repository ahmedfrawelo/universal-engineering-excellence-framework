#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "${1:-$(dirname -- "$0")/..}" && pwd)

for file in \
  framework/61-project-modernization/00-project-modernization-system.md \
  framework/61-project-modernization/02-behavior-preserving-refactoring.md \
  framework/61-project-modernization/03-dead-and-obsolete-code.md \
  framework/61-project-modernization/05-technology-currency-assessment.md \
  framework/61-project-modernization/06-upgrade-decision-and-execution.md \
  framework/61-project-modernization/07-performance-freshness-and-lazy-loading.md \
  framework/27-quality-gates/34-project-modernization-and-runtime-gate.md \
  framework/29-checklists/43-project-modernization-and-runtime-checklist.md \
  framework/38-templates/30-project-modernization-plan-template.md \
  scripts/project-technology-inventory.mjs; do
  [ -f "$ROOT/$file" ] || { echo "Missing modernization contract: $file" >&2; exit 1; }
done

for term in WebSocket Origin SSE Retry-After backpressure no-page-reload; do
  grep -Fq "$term" "$ROOT/framework/47-theme-responsive-interaction-security-performance/51-global-live-refresh.md" || { echo "Global live-refresh contract missing: $term" >&2; exit 1; }
done
for term in 'request waterfalls' 'duplicate vendor chunks' 'reserved layout' 'first user request' 'measured before/after evidence'; do
  grep -Fq "$term" "$ROOT/framework/47-theme-responsive-interaction-security-performance/50-application-lazy-loading.md" || { echo "Application lazy-loading contract missing: $term" >&2; exit 1; }
done

node "$ROOT/scripts/project-technology-inventory.mjs" "$ROOT" | node -e '
  let text = "";
  process.stdin.on("data", chunk => text += chunk);
  process.stdin.on("end", () => {
    const result = JSON.parse(text);
    if (!Array.isArray(result.entries) || !result.entries.length || !Array.isArray(result.ecosystems)) process.exit(1);
  });
'
echo 'Project modernization contract tests passed'
