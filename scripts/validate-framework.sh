#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
for f in README.md INSTALL.md QUICK_START.md VERSION.md CHANGELOG.md LICENSE CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md ROADMAP.md BUILD_PROGRESS.md; do
  [ -e "$ROOT/$f" ] || { echo "Missing $f" >&2; exit 1; }
done
for d in framework scripts docs examples tools; do
  [ -d "$ROOT/$d" ] || { echo "Missing $d" >&2; exit 1; }
done
required_acceptance="framework/38-templates/feature-implementation-template.md framework/38-templates/component-creation-template.md framework/38-templates/api-creation-template.md framework/38-templates/database-change-template.md framework/38-templates/adr-template.md framework/38-templates/pull-request-template.md framework/38-templates/security-review-template.md framework/38-templates/performance-review-template.md framework/38-templates/risk-assessment-template.md framework/38-templates/incident-report-template.md framework/38-templates/engineering-review-template.md framework/26-decision-graphs/component-decision-graph.md framework/26-decision-graphs/file-folder-decision-graph.md framework/26-decision-graphs/dependency-decision-graph.md framework/26-decision-graphs/api-decision-graph.md framework/26-decision-graphs/database-decision-graph.md framework/26-decision-graphs/state-management-decision-graph.md framework/26-decision-graphs/caching-decision-graph.md framework/26-decision-graphs/security-decision-graph.md framework/26-decision-graphs/performance-decision-graph.md framework/26-decision-graphs/refactoring-decision-graph.md framework/26-decision-graphs/ui-decision-graph.md framework/26-decision-graphs/architecture-decision-graph.md framework/27-quality-gates/requirements-gate.md framework/27-quality-gates/architecture-gate.md framework/27-quality-gates/code-quality-gate.md framework/27-quality-gates/security-gate.md framework/27-quality-gates/performance-gate.md framework/27-quality-gates/database-gate.md framework/27-quality-gates/api-gate.md framework/27-quality-gates/ui-gate.md framework/27-quality-gates/ux-gate.md framework/27-quality-gates/accessibility-gate.md framework/27-quality-gates/testing-gate.md framework/27-quality-gates/documentation-gate.md framework/27-quality-gates/production-gate.md framework/27-quality-gates/enterprise-gate.md framework/27-quality-gates/final-gate.md framework/28-scorecards/engineering-scorecard.md framework/28-scorecards/architecture-scorecard.md framework/28-scorecards/code-quality-scorecard.md framework/28-scorecards/security-scorecard.md framework/28-scorecards/performance-scorecard.md framework/28-scorecards/scalability-scorecard.md framework/28-scorecards/maintainability-scorecard.md framework/28-scorecards/ui-scorecard.md framework/28-scorecards/ux-scorecard.md framework/28-scorecards/accessibility-scorecard.md framework/28-scorecards/production-readiness-scorecard.md framework/28-scorecards/enterprise-readiness-scorecard.md framework/28-scorecards/final-review-scorecard.md"
for f in $required_acceptance; do
  [ -f "$ROOT/$f" ] || { echo "Missing $f" >&2; exit 1; }
done
for p in "$ROOT"/framework/[0-9][0-9]-*; do
  [ -f "$p/README.md" ] || { echo "Missing $p/README.md" >&2; exit 1; }
  [ -f "$p/INDEX.md" ] || { echo "Missing $p/INDEX.md" >&2; exit 1; }
done
count="$(find "$ROOT" -name '*.md' -type f | wc -l)"
[ "$count" -ge 160 ] || { echo "Markdown count below minimum: $count" >&2; exit 1; }
if find "$ROOT" -name '*.md' -type f -size 0c | grep .; then echo "Empty Markdown files found" >&2; exit 1; fi
grep -q "00-foundation" "$ROOT/framework/MASTER_INDEX.md"
grep -q "27-quality-gates" "$ROOT/framework/MASTER_INDEX.md"
grep -q "38-templates" "$ROOT/framework/MASTER_INDEX.md"
echo "UEEF validation passed"
echo "Markdown file count: $count"
echo "Framework pack count: $(find "$ROOT/framework" -maxdepth 1 -type d -name '[0-9][0-9]-*' | wc -l)"
echo "Total file count: $(find "$ROOT" -type f | wc -l)"
