#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
for f in README.md INSTALL.md QUICK_START.md VERSION.md CHANGELOG.md LICENSE CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md ROADMAP.md BUILD_PROGRESS.md UEEF-LOADER.md; do
  [ -e "$ROOT/$f" ] || { echo "Missing $f" >&2; exit 1; }
done
for d in framework scripts docs examples tools; do
  [ -d "$ROOT/$d" ] || { echo "Missing $d" >&2; exit 1; }
done
[ -f "$ROOT/framework/01-core/13-autonomy-and-confirmation-policy.md" ] || { echo "Missing autonomy policy" >&2; exit 1; }
[ -f "$ROOT/framework/01-core/14-delivery-continuation-policy.md" ] || { echo "Missing delivery continuation policy" >&2; exit 1; }
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
grep -q "51-browser-session-control" "$ROOT/framework/MASTER_INDEX.md"
grep -q "52-workspace-hygiene" "$ROOT/framework/MASTER_INDEX.md"
grep -q "53-skeleton-loading" "$ROOT/framework/MASTER_INDEX.md"
grep -q "54-design-intelligence" "$ROOT/framework/MASTER_INDEX.md"
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
  release-manifest.json docs/releases/v1.4.0.md docs/releases/v1.4.1.md docs/releases/v1.4.2.md docs/releases/v1.4.3.md docs/releases/v1.4.4.md; do
  [ -f "$ROOT/$f" ] || { echo "Missing $f" >&2; exit 1; }
done
grep -q "Existing theme inspected:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Security and performance" "$ROOT/framework/01-core/00-core-system.md"
grep -q "component registry" "$ROOT/framework/01-core/00-core-system.md"
grep -q "Proceed autonomously through ordinary scoped engineering work" "$ROOT/framework/01-core/00-core-system.md"
grep -q "not a reason to suspend execution" "$ROOT/UEEF-LOADER.md"
grep -q "Existing project UI searched:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Affected baseline recorded:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Environment Ready:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "User-owned browser selected:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Platform Chrome permission granted:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Active window identity verified:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Automation banner visible:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Connector-created window:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Skeleton system selected:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Skeleton parity verified:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "54-design-intelligence" "$ROOT/framework/MASTER_INDEX.md"
grep -q "Design source of truth identified:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Design intelligence gate:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "55-continuous-assurance" "$ROOT/framework/MASTER_INDEX.md"
grep -q "Continuous assurance audit run:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "56-data-grid-platform" "$ROOT/framework/MASTER_INDEX.md"
grep -q "Existing table baseline inspected:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Data grid platform gate:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Advanced grid capabilities verified:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Production data delivery controls verified:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Shell baseline extracted:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Shell visual/performance gate:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Live refresh no-reload proof verified:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Realtime security and burst-performance proof verified:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "First-viewport composition reviewed:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Visual evidence gate:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
[ -f "$ROOT/framework/27-quality-gates/28-data-grid-platform-gate.md" ] || { echo "Missing data-grid gate" >&2; exit 1; }
[ -f "$ROOT/framework/29-checklists/37-data-grid-platform-checklist.md" ] || { echo "Missing data-grid checklist" >&2; exit 1; }
[ -f "$ROOT/scripts/ueef-audit.ps1" ] || { echo "Missing audit runner" >&2; exit 1; }
[ -f "$ROOT/scripts/ueef-audit.sh" ] || { echo "Missing Unix audit runner" >&2; exit 1; }
[ -f "$ROOT/framework/27-quality-gates/27-continuous-assurance-gate.md" ] || { echo "Missing assurance gate" >&2; exit 1; }
[ -f "$ROOT/scripts/extract-design-system.mjs" ] || { echo "Missing design extractor" >&2; exit 1; }
[ -f "$ROOT/scripts/recommend-design-system.mjs" ] || { echo "Missing design recommendation analyzer" >&2; exit 1; }
[ -f "$ROOT/framework/27-quality-gates/26-design-intelligence-gate.md" ] || { echo "Missing design intelligence gate" >&2; exit 1; }
[ -f "$ROOT/framework/29-checklists/35-design-intelligence-checklist.md" ] || { echo "Missing design intelligence checklist" >&2; exit 1; }
[ -f "$ROOT/framework/27-quality-gates/23-browser-session-control-gate.md" ] || { echo "Missing browser session gate" >&2; exit 1; }
[ -f "$ROOT/framework/29-checklists/32-browser-session-control-checklist.md" ] || { echo "Missing browser session checklist" >&2; exit 1; }
[ -f "$ROOT/framework/51-browser-session-control/09-platform-authorized-chrome-control.md" ] || { echo "Missing platform-authorized Chrome-control module" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v1.5.0.md" ] || { echo "Missing browser session release notes" >&2; exit 1; }
[ -f "$ROOT/scripts/cleanup-workspace.ps1" ] || { echo "Missing cleanup script" >&2; exit 1; }
[ -f "$ROOT/scripts/cleanup-workspace.sh" ] || { echo "Missing cleanup script" >&2; exit 1; }
[ -f "$ROOT/framework/27-quality-gates/24-workspace-hygiene-gate.md" ] || { echo "Missing hygiene gate" >&2; exit 1; }
[ -f "$ROOT/framework/29-checklists/33-workspace-hygiene-checklist.md" ] || { echo "Missing hygiene checklist" >&2; exit 1; }
[ -f "$ROOT/framework/27-quality-gates/25-skeleton-loading-gate.md" ] || { echo "Missing skeleton gate" >&2; exit 1; }
[ -f "$ROOT/framework/29-checklists/34-skeleton-loading-checklist.md" ] || { echo "Missing skeleton checklist" >&2; exit 1; }
[ -f "$ROOT/framework/38-templates/22-skeleton-loading-contract-template.md" ] || { echo "Missing skeleton template" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v1.7.0.md" ] || { echo "Missing skeleton release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v1.8.0.md" ] || { echo "Missing design intelligence release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v1.8.1.md" ] || { echo "Missing design review release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v1.9.0.md" ] || { echo "Missing assurance release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v1.9.1.md" ] || { echo "Missing hardening release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.0.0.md" ] || { echo "Missing data-grid release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.0.1.md" ] || { echo "Missing production data delivery release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.0.2.md" ] || { echo "Missing data-grid operational release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.1.0.md" ] || { echo "Missing application-shell release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.1.1.md" ] || { echo "Missing live-refresh release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.2.0.md" ] || { echo "Missing visual composition release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.2.1.md" ] || { echo "Missing browser recovery release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.2.2.md" ] || { echo "Missing browser evidence communication release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.3.0.md" ] || { echo "Missing autonomous browser-control release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.3.1.md" ] || { echo "Missing browser-control runtime-health release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.3.2.md" ] || { echo "Missing browser-control rollback release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.4.0.md" ] || { echo "Missing platform-authorized Chrome-control release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.4.1.md" ] || { echo "Missing user-owned Chrome site-opening release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.4.2.md" ] || { echo "Missing autonomy policy release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.4.3.md" ] || { echo "Missing delivery continuation release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.4.4.md" ] || { echo "Missing global delivery continuation release notes" >&2; exit 1; }
version="$(sed -n 's/.*version: \([0-9][0-9.]*\).*/\1/p' "$ROOT/VERSION.md" | head -n 1)"
grep -q "\"version\": \"$version\"" "$ROOT/release-manifest.json" || { echo "Version and release manifest do not match" >&2; exit 1; }
for f in framework/50-environment-bootstrap/README.md framework/50-environment-bootstrap/INDEX.md framework/50-environment-bootstrap/00-environment-bootstrap.md framework/50-environment-bootstrap/01-profile-selection.md framework/50-environment-bootstrap/02-core-profile.md framework/50-environment-bootstrap/03-frontend-profile.md framework/50-environment-bootstrap/04-backend-profile.md framework/50-environment-bootstrap/05-database-profile.md framework/50-environment-bootstrap/06-uiux-profile.md framework/50-environment-bootstrap/07-devops-profile.md framework/50-environment-bootstrap/08-ai-profile.md framework/50-environment-bootstrap/09-optional-profile.md framework/50-environment-bootstrap/10-dependency-levels.md framework/50-environment-bootstrap/11-detection-and-installation.md framework/50-environment-bootstrap/12-mcp-detection.md framework/50-environment-bootstrap/13-runtime-bootstrap-sequence.md; do
  [ -f "$ROOT/$f" ] || { echo "Missing $f" >&2; exit 1; }
done
echo "UEEF validation passed"
echo "Markdown file count: $count"
echo "Framework pack count: $(find "$ROOT/framework" -maxdepth 1 -type d -name '[0-9][0-9]-*' | wc -l)"
echo "Total file count: $(find "$ROOT" -type f | wc -l)"
