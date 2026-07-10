#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
for f in README.md INSTALL.md QUICK_START.md VERSION.md CHANGELOG.md LICENSE CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md ROADMAP.md BUILD_PROGRESS.md UEEF-LOADER.md; do
  [ -e "$ROOT/$f" ] || { echo "Missing $f" >&2; exit 1; }
done
for d in framework scripts docs examples tools; do
  [ -d "$ROOT/$d" ] || { echo "Missing $d" >&2; exit 1; }
done
required_acceptance="docs/token-efficiency.md framework/01-core/00-boot-loader.md docs/runtime-hardening.md scripts/write-active-state.ps1 scripts/select-quality-gates.ps1 scripts/check-runtime-drift.ps1 scripts/sync-runtime.ps1 scripts/ueef-status.ps1 scripts/ueef-status.sh docs/verify-ueef-is-active.md framework/01-core/10-runtime-activation-proof.md framework/27-quality-gates/16-ueef-activation-gate.md examples/generic-ai/runtime-check-example.md framework/38-templates/feature-implementation-template.md framework/38-templates/component-creation-template.md framework/38-templates/api-creation-template.md framework/38-templates/database-change-template.md framework/38-templates/adr-template.md framework/38-templates/pull-request-template.md framework/38-templates/security-review-template.md framework/38-templates/performance-review-template.md framework/38-templates/risk-assessment-template.md framework/38-templates/incident-report-template.md framework/38-templates/engineering-review-template.md framework/26-decision-graphs/component-decision-graph.md framework/26-decision-graphs/file-folder-decision-graph.md framework/26-decision-graphs/dependency-decision-graph.md framework/26-decision-graphs/api-decision-graph.md framework/26-decision-graphs/database-decision-graph.md framework/26-decision-graphs/state-management-decision-graph.md framework/26-decision-graphs/caching-decision-graph.md framework/26-decision-graphs/security-decision-graph.md framework/26-decision-graphs/performance-decision-graph.md framework/26-decision-graphs/refactoring-decision-graph.md framework/26-decision-graphs/ui-decision-graph.md framework/26-decision-graphs/architecture-decision-graph.md framework/27-quality-gates/requirements-gate.md framework/27-quality-gates/architecture-gate.md framework/27-quality-gates/code-quality-gate.md framework/27-quality-gates/security-gate.md framework/27-quality-gates/performance-gate.md framework/27-quality-gates/database-gate.md framework/27-quality-gates/api-gate.md framework/27-quality-gates/ui-gate.md framework/27-quality-gates/ux-gate.md framework/27-quality-gates/accessibility-gate.md framework/27-quality-gates/testing-gate.md framework/27-quality-gates/documentation-gate.md framework/27-quality-gates/production-gate.md framework/27-quality-gates/enterprise-gate.md framework/27-quality-gates/final-gate.md framework/28-scorecards/engineering-scorecard.md framework/28-scorecards/architecture-scorecard.md framework/28-scorecards/code-quality-scorecard.md framework/28-scorecards/security-scorecard.md framework/28-scorecards/performance-scorecard.md framework/28-scorecards/scalability-scorecard.md framework/28-scorecards/maintainability-scorecard.md framework/28-scorecards/ui-scorecard.md framework/28-scorecards/ux-scorecard.md framework/28-scorecards/accessibility-scorecard.md framework/28-scorecards/production-readiness-scorecard.md framework/28-scorecards/enterprise-readiness-scorecard.md framework/28-scorecards/final-review-scorecard.md"
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
grep -q "45-identity-access-application-models" "$ROOT/framework/MASTER_INDEX.md"
grep -q "46-design-system-consistency-reuse" "$ROOT/framework/MASTER_INDEX.md"
grep -q "47-theme-responsive-interaction-security-performance" "$ROOT/framework/MASTER_INDEX.md"
grep -q "48-design-governance" "$ROOT/framework/MASTER_INDEX.md"
grep -q "49-engineering-guardian" "$ROOT/framework/MASTER_INDEX.md"
grep -q "50-environment-bootstrap" "$ROOT/framework/MASTER_INDEX.md"
for f in \
  framework/27-quality-gates/19-theme-responsive-interaction-security-performance-gate.md \
  framework/28-scorecards/15-theme-responsive-interaction-security-performance-scorecard.md \
  framework/26-decision-graphs/19-theme-architecture-decision-graph.md \
  framework/26-decision-graphs/20-responsive-component-decision-graph.md \
  framework/26-decision-graphs/21-overlay-behavior-decision-graph.md \
  framework/26-decision-graphs/22-security-hardening-decision-graph.md \
  framework/26-decision-graphs/23-performance-optimization-decision-graph.md \
  framework/29-checklists/23-theme-review-checklist.md \
  framework/29-checklists/24-dark-mode-review-checklist.md \
  framework/29-checklists/25-responsive-first-checklist.md \
  framework/29-checklists/26-dropdown-panel-overlay-checklist.md \
  framework/29-checklists/27-security-hardening-checklist.md \
  framework/29-checklists/28-extreme-performance-checklist.md \
  framework/38-templates/16-theme-definition-template.md \
  framework/38-templates/17-responsive-component-contract-template.md \
  framework/38-templates/18-overlay-interaction-contract-template.md \
  framework/38-templates/19-security-review-report-template.md \
  framework/38-templates/20-performance-budget-template.md \
  framework/27-quality-gates/20-design-governance-gate.md \
  framework/28-scorecards/16-design-governance-scorecard.md \
  framework/29-checklists/29-design-governance-checklist.md \
  framework/38-templates/21-design-governance-review-template.md \
  framework/27-quality-gates/21-engineering-guardian-gate.md \
  framework/28-scorecards/17-engineering-health-scorecard.md \
  framework/29-checklists/30-engineering-guardian-checklist.md \
  scripts/environment-bootstrap.ps1 scripts/environment-bootstrap.sh \
  framework/27-quality-gates/22-environment-bootstrap-gate.md \
  framework/28-scorecards/18-environment-readiness-scorecard.md \
  framework/29-checklists/31-environment-bootstrap-checklist.md \
  release-manifest.json docs/releases/v1.4.0.md; do
  [ -f "$ROOT/$f" ] || { echo "Missing $f" >&2; exit 1; }
done
grep -q "Existing theme inspected:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Security and performance" "$ROOT/framework/01-core/00-core-system.md"
grep -q "component registry" "$ROOT/framework/01-core/00-core-system.md"
grep -q "Existing project UI searched:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Affected baseline recorded:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Environment Ready:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
echo "UEEF validation passed"
echo "Markdown file count: $count"
echo "Framework pack count: $(find "$ROOT/framework" -maxdepth 1 -type d -name '[0-9][0-9]-*' | wc -l)"
echo "Total file count: $(find "$ROOT" -type f | wc -l)"
