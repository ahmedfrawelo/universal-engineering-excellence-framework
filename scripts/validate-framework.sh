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
grep -q "58-agent-model-orchestration" "$ROOT/framework/MASTER_INDEX.md"
grep -q "59-skill-invocation-protocol" "$ROOT/framework/MASTER_INDEX.md"
grep -q "60-spec-driven-development" "$ROOT/framework/MASTER_INDEX.md"
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
  scripts/test-environment-bootstrap.ps1 \
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
grep -q "Agent and model routing:" "$ROOT/scripts/sync-runtime.ps1"
grep -q "not a reason to suspend execution" "$ROOT/scripts/sync-runtime.ps1"
grep -q "Local command autonomy:" "$ROOT/scripts/sync-runtime.ps1"
grep -q "Design engineering skill routing:" "$ROOT/scripts/sync-runtime.ps1"
grep -q "File, folder, and size discipline:" "$ROOT/scripts/sync-runtime.ps1" || { echo "Runtime generator missing file/folder policy" >&2; exit 1; }
grep -q "Backend and frontend performance:" "$ROOT/scripts/sync-runtime.ps1" || { echo "Runtime generator missing performance policy" >&2; exit 1; }
grep -q "Response quality:" "$ROOT/scripts/sync-runtime.ps1" || { echo "Runtime generator missing response policy" >&2; exit 1; }
grep -q "Task scope discipline:" "$ROOT/scripts/sync-runtime.ps1" || { echo "Runtime generator missing scope policy" >&2; exit 1; }
grep -q "Prevent over-rendering end to end" "$ROOT/scripts/sync-runtime.ps1" || { echo "Runtime generator missing over-render policy" >&2; exit 1; }
grep -q "Animations must be smooth" "$ROOT/scripts/sync-runtime.ps1" || { echo "Runtime generator missing animation policy" >&2; exit 1; }
grep -q "SSR, SSG, streaming" "$ROOT/scripts/sync-runtime.ps1" || { echo "Runtime generator missing SSR policy" >&2; exit 1; }
grep -q "Reusable behavior, UI, validation" "$ROOT/scripts/sync-runtime.ps1" || { echo "Runtime generator missing shared-first policy" >&2; exit 1; }
grep -q "Before creating custom UI or behavior" "$ROOT/scripts/sync-runtime.ps1" || { echo "Runtime generator missing design-system-first policy" >&2; exit 1; }
grep -q "Large-project reuse:" "$ROOT/scripts/sync-runtime.ps1" || { echo "Runtime generator missing large-project reuse section" >&2; exit 1; }
grep -q "Discover module boundaries" "$ROOT/scripts/sync-runtime.ps1" || { echo "Runtime generator missing large-project discovery rule" >&2; exit 1; }
for skill in emil-design-eng review-animations improve-animations animation-vocabulary apple-design; do
  grep -q "$skill" "$ROOT/scripts/sync-runtime.ps1" || { echo "Runtime generator missing design skill: $skill" >&2; exit 1; }
  grep -q "$skill" "$ROOT/scripts/environment-bootstrap.sh" || { echo "Unix bootstrap missing design skill: $skill" >&2; exit 1; }
done
grep -q "Existing project UI searched:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Affected baseline recorded:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Environment Ready:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "User-owned browser/profile verified:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Chrome readiness flow completed:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Extension/tab-claim authorization granted:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Exact user.openTabs() object claimed:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Automatic ownership repair run when needed:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Existing window state preserved:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Control provenance:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Banner classification:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Skeleton system selected:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Skeleton parity verified:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Skeleton timing policy selected:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Delayed reveal verified:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Minimum visible duration verified:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "SSR/hydration parity verified:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Shared skeleton API contract verified:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Skeleton family owner and canonical public import verified:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Cancellation and refresh behavior verified:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
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
grep -q "Agent route tier:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Independent workstreams:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Named model availability verified:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
grep -q "Agent model routing gate:" "$ROOT/framework/03-runtime/00-runtime-sequence.md"
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
[ -f "$ROOT/framework/51-browser-session-control/10-window-state-preservation.md" ] || { echo "Missing browser window-state-preservation module" >&2; exit 1; }
[ -f "$ROOT/framework/51-browser-session-control/11-control-surface-selection.md" ] || { echo "Missing browser control-surface-selection module" >&2; exit 1; }
[ -f "$ROOT/framework/51-browser-session-control/12-cross-session-evidence-handoff.md" ] || { echo "Missing cross-session browser-evidence handoff module" >&2; exit 1; }
[ -f "$ROOT/framework/51-browser-session-control/13-user-facing-recovery-protocol.md" ] || { echo "Missing user-facing browser recovery module" >&2; exit 1; }
[ -f "$ROOT/framework/51-browser-session-control/14-automatic-tab-ownership-recovery.md" ] || { echo "Missing automatic tab ownership recovery module" >&2; exit 1; }
[ -f "$ROOT/framework/51-browser-session-control/15-chrome-control-readiness.md" ] || { echo "Missing Chrome control readiness module" >&2; exit 1; }
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
[ -f "$ROOT/docs/releases/v2.4.5.md" ] || { echo "Missing local command autonomy release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.4.6.md" ] || { echo "Missing browser window-state release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.5.0.md" ] || { echo "Missing browser control-surface release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.6.0.md" ] || { echo "Missing agent orchestration release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.7.0.md" ] || { echo "Missing design engineering skills release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.7.1.md" ] || { echo "Missing full-project hardening release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.0.md" ] || { echo "Missing agent-routing activation release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.1.md" ] || { echo "Missing mandatory agent evidence release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.2.md" ] || { echo "Missing browser control alignment release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.3.md" ] || { echo "Missing minimized browser control release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.4.md" ] || { echo "Missing delivery continuation hardening release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.5.md" ] || { echo "Missing active-goal finalization release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.6.md" ] || { echo "Missing deterministic Chrome routing release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.7.md" ] || { echo "Missing Chrome bridge recovery release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.8.md" ] || { echo "Missing browser evidence handoff release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.9.md" ] || { echo "Missing silent browser recovery release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.10.md" ] || { echo "Missing enforced browser-recovery release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.11.md" ] || { echo "Missing stale tab ownership release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.12.md" ] || { echo "Missing autonomous tab ownership recovery release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.13.md" ] || { echo "Missing non-destructive runtime sync release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.14.md" ] || { echo "Missing bootstrap runtime-path normalization release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.15.md" ] || { echo "Missing file organization and SSR release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.16.md" ] || { echo "Missing shared-first reuse release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.17.md" ] || { echo "Missing project-context release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.18.md" ] || { echo "Missing skill invocation protocol release notes" >&2; exit 1; }
[ -f "$ROOT/docs/third-party/superpowers-attribution.md" ] || { echo "Missing Superpowers attribution" >&2; exit 1; }
[ -f "$ROOT/framework/59-skill-invocation-protocol/README.md" ] || { echo "Missing skill invocation protocol README" >&2; exit 1; }
[ -f "$ROOT/framework/59-skill-invocation-protocol/INDEX.md" ] || { echo "Missing skill invocation protocol index" >&2; exit 1; }
[ -f "$ROOT/framework/59-skill-invocation-protocol/00-skill-invocation-protocol-system.md" ] || { echo "Missing skill invocation protocol system" >&2; exit 1; }
[ -f "$ROOT/framework/59-skill-invocation-protocol/01-skill-discovery-and-routing.md" ] || { echo "Missing skill discovery module" >&2; exit 1; }
[ -f "$ROOT/framework/59-skill-invocation-protocol/02-red-flag-detection.md" ] || { echo "Missing red flag module" >&2; exit 1; }
[ -f "$ROOT/framework/59-skill-invocation-protocol/03-spec-plan-execution-chain.md" ] || { echo "Missing spec-plan module" >&2; exit 1; }
[ -f "$ROOT/framework/59-skill-invocation-protocol/04-tdd-and-evidence-loop.md" ] || { echo "Missing TDD evidence module" >&2; exit 1; }
[ -f "$ROOT/framework/59-skill-invocation-protocol/05-subagent-review-chain.md" ] || { echo "Missing subagent review module" >&2; exit 1; }
[ -f "$ROOT/framework/59-skill-invocation-protocol/06-skill-authoring-quality.md" ] || { echo "Missing skill authoring module" >&2; exit 1; }
[ -f "$ROOT/framework/27-quality-gates/32-skill-invocation-protocol-gate.md" ] || { echo "Missing skill invocation protocol gate" >&2; exit 1; }
[ -f "$ROOT/framework/29-checklists/41-skill-invocation-protocol-checklist.md" ] || { echo "Missing skill invocation protocol checklist" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.19.md" ] || { echo "Missing spec-driven release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.20.md" ] || { echo "Missing runtime hardening release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.21.md" ] || { echo "Missing mixed-direction response release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.22.md" ] || { echo "Missing mandatory mixed-direction response release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.23.md" ] || { echo "Missing screenshot-block prevention release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.8.24.md" ] || { echo "Missing Chrome readiness release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.9.0.md" ] || { echo "Missing skeleton hardening release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.9.1.md" ] || { echo "Missing component-family organization release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.9.2.md" ] || { echo "Missing release-consistency hardening release notes" >&2; exit 1; }
[ -f "$ROOT/docs/releases/v2.10.0.md" ] || { echo "Missing project-modernization release notes" >&2; exit 1; }
[ -f "$ROOT/framework/61-project-modernization/00-project-modernization-system.md" ] || { echo "Missing project modernization system" >&2; exit 1; }
[ -f "$ROOT/framework/47-theme-responsive-interaction-security-performance/50-application-lazy-loading.md" ] || { echo "Missing application lazy-loading contract" >&2; exit 1; }
[ -f "$ROOT/framework/47-theme-responsive-interaction-security-performance/51-global-live-refresh.md" ] || { echo "Missing global live-refresh contract" >&2; exit 1; }
[ -f "$ROOT/framework/27-quality-gates/34-project-modernization-and-runtime-gate.md" ] || { echo "Missing project modernization gate" >&2; exit 1; }
[ -f "$ROOT/docs/third-party/spec-kit-attribution.md" ] || { echo "Missing Spec Kit attribution" >&2; exit 1; }
[ -f "$ROOT/framework/60-spec-driven-development/README.md" ] || { echo "Missing spec-driven README" >&2; exit 1; }
[ -f "$ROOT/framework/60-spec-driven-development/INDEX.md" ] || { echo "Missing spec-driven index" >&2; exit 1; }
[ -f "$ROOT/framework/60-spec-driven-development/00-spec-driven-development-system.md" ] || { echo "Missing spec-driven system" >&2; exit 1; }
[ -f "$ROOT/framework/60-spec-driven-development/01-constitution-and-principles.md" ] || { echo "Missing spec constitution module" >&2; exit 1; }
[ -f "$ROOT/framework/60-spec-driven-development/02-specification-artifact.md" ] || { echo "Missing spec artifact module" >&2; exit 1; }
[ -f "$ROOT/framework/60-spec-driven-development/03-clarification-and-ambiguity.md" ] || { echo "Missing spec clarification module" >&2; exit 1; }
[ -f "$ROOT/framework/60-spec-driven-development/04-technical-plan-translation.md" ] || { echo "Missing spec plan module" >&2; exit 1; }
[ -f "$ROOT/framework/60-spec-driven-development/05-task-breakdown-and-parallelization.md" ] || { echo "Missing spec task breakdown module" >&2; exit 1; }
[ -f "$ROOT/framework/60-spec-driven-development/06-consistency-analysis-and-checklists.md" ] || { echo "Missing spec consistency module" >&2; exit 1; }
[ -f "$ROOT/framework/60-spec-driven-development/07-implementation-and-convergence.md" ] || { echo "Missing spec convergence module" >&2; exit 1; }
[ -f "$ROOT/framework/60-spec-driven-development/08-extension-preset-bundle-governance.md" ] || { echo "Missing spec extension governance module" >&2; exit 1; }
[ -f "$ROOT/framework/60-spec-driven-development/09-third-party-attribution.md" ] || { echo "Missing spec third-party attribution module" >&2; exit 1; }
[ -f "$ROOT/framework/27-quality-gates/33-spec-driven-development-gate.md" ] || { echo "Missing spec-driven gate" >&2; exit 1; }
[ -f "$ROOT/framework/29-checklists/42-spec-driven-development-checklist.md" ] || { echo "Missing spec-driven checklist" >&2; exit 1; }
[ -f "$ROOT/framework/38-templates/29-spec-driven-development-template.md" ] || { echo "Missing spec-driven template" >&2; exit 1; }
[ -f "$ROOT/assets/ueef-display.json" ] || { echo "Missing UEEF display metadata" >&2; exit 1; }
[ -f "$ROOT/assets/ueef-skill-icon.svg" ] || { echo "Missing UEEF skill icon asset" >&2; exit 1; }
[ -f "$ROOT/scripts/project-context-map.ps1" ] || { echo "Missing project context map script" >&2; exit 1; }
[ -f "$ROOT/scripts/project-context-map.sh" ] || { echo "Missing Unix project context map script" >&2; exit 1; }
grep -q 'apply both `ui-ux-pro-max` and `impeccable` together' "$ROOT/framework/01-core/00-core-system.md" || { echo "Core missing UIUX skill-pair rule" >&2; exit 1; }
grep -q 'Place every new file under an existing owned feature' "$ROOT/framework/01-core/00-core-system.md" || { echo "Core missing owned-file rule" >&2; exit 1; }
grep -q 'standalone-file system' "$ROOT/framework/01-core/00-core-system.md" || { echo "Core missing standalone-file rule" >&2; exit 1; }
grep -q 'Keep files small enough to review and maintain' "$ROOT/framework/01-core/00-core-system.md" || { echo "Core missing file-size rule" >&2; exit 1; }
grep -q "Final responses must answer" "$ROOT/framework/01-core/00-core-system.md" || { echo "Core missing response-quality rule" >&2; exit 1; }
grep -q 'Runtime drift:' "$ROOT/scripts/ueef-status.ps1" || { echo "Status script missing runtime drift field" >&2; exit 1; }
grep -q 'emil-design-eng' "$ROOT/scripts/select-quality-gates.ps1" || { echo "Quality gate selector missing motion skill route" >&2; exit 1; }
grep -q 'animation' "$ROOT/scripts/select-quality-gates.ps1" || { echo "Quality gate selector missing animation route" >&2; exit 1; }
grep -q 'superpowers' "$ROOT/scripts/select-quality-gates.ps1" || { echo "Quality gate selector missing Superpowers route" >&2; exit 1; }
grep -q '32-skill-invocation-protocol-gate' "$ROOT/scripts/select-quality-gates.ps1" || { echo "Quality gate selector missing skill protocol gate" >&2; exit 1; }
grep -q 'Skill invocation protocol:' "$ROOT/scripts/sync-runtime.ps1" || { echo "Runtime sync missing skill protocol section" >&2; exit 1; }
grep -q 'TDD or an equivalent evidence loop' "$ROOT/scripts/sync-runtime.ps1" || { echo "Runtime sync missing skill evidence loop" >&2; exit 1; }
grep -q 'Skill candidates:' "$ROOT/framework/03-runtime/00-runtime-sequence.md" || { echo "Runtime sequence missing skill candidates" >&2; exit 1; }
grep -q 'Red flags checked:' "$ROOT/framework/03-runtime/00-runtime-sequence.md" || { echo "Runtime sequence missing red flag field" >&2; exit 1; }
grep -q 'MIT License' "$ROOT/docs/third-party/superpowers-attribution.md" || { echo "Superpowers attribution missing MIT License" >&2; exit 1; }
grep -q '6fd4507659784c351abbd2bc264c7162cfd386dc' "$ROOT/docs/third-party/superpowers-attribution.md" || { echo "Superpowers attribution missing reviewed commit" >&2; exit 1; }
grep -q 'spec kit' "$ROOT/scripts/select-quality-gates.ps1" || { echo "Quality gate selector missing Spec Kit route" >&2; exit 1; }
grep -q '33-spec-driven-development-gate' "$ROOT/scripts/select-quality-gates.ps1" || { echo "Quality gate selector missing spec-driven gate" >&2; exit 1; }
grep -q 'Spec-driven development:' "$ROOT/scripts/sync-runtime.ps1" || { echo "Runtime sync missing spec-driven section" >&2; exit 1; }
grep -q 'specification the source of truth' "$ROOT/scripts/sync-runtime.ps1" || { echo "Runtime sync missing spec-driven source-of-truth rule" >&2; exit 1; }
grep -q 'Spec-driven applicability:' "$ROOT/framework/03-runtime/00-runtime-sequence.md" || { echo "Runtime sequence missing spec-driven applicability" >&2; exit 1; }
grep -q 'Convergence evidence:' "$ROOT/framework/03-runtime/00-runtime-sequence.md" || { echo "Runtime sequence missing convergence evidence" >&2; exit 1; }
grep -q 'MIT License' "$ROOT/docs/third-party/spec-kit-attribution.md" || { echo "Spec Kit attribution missing MIT License" >&2; exit 1; }
grep -q 'fd101d531eaec8a1e709db2f37632bc93b6ce4d6' "$ROOT/docs/third-party/spec-kit-attribution.md" || { echo "Spec Kit attribution missing reviewed commit" >&2; exit 1; }
grep -q 'server-side filtering, sorting, pagination, aggregation' "$ROOT/framework/01-core/00-core-system.md" || { echo "Core missing backend data-shaping rule" >&2; exit 1; }
grep -q 'evaluate SSR, SSG, streaming' "$ROOT/framework/01-core/00-core-system.md" || { echo "Core missing SSR rule" >&2; exit 1; }
grep -q 'Prevent over-rendering on both frontend and backend-driven UI paths' "$ROOT/framework/01-core/00-core-system.md" || { echo "Core missing over-render rule" >&2; exit 1; }
grep -q 'Animations must be smooth' "$ROOT/framework/01-core/00-core-system.md" || { echo "Core missing animation smoothness rule" >&2; exit 1; }
grep -q "Stay inside the user's requested task scope" "$ROOT/framework/01-core/00-core-system.md" || { echo "Core missing task-scope rule" >&2; exit 1; }
grep -q 'Task Scope Discipline' "$ROOT/framework/01-core/00-core-system.md" || { echo "Core missing task-scope section" >&2; exit 1; }
grep -q 'Shared-first rule' "$ROOT/framework/01-core/00-core-system.md" || { echo "Core missing shared-first rule" >&2; exit 1; }
grep -q 'Before creating custom UI or custom behavior' "$ROOT/framework/01-core/00-core-system.md" || { echo "Core missing custom-before-search rule" >&2; exit 1; }
grep -q 'Large Project Reuse Requirements' "$ROOT/framework/01-core/00-core-system.md" || { echo "Core missing large-project reuse section" >&2; exit 1; }
grep -q 'Record the reuse decision' "$ROOT/framework/01-core/00-core-system.md" || { echo "Core missing reuse-decision rule" >&2; exit 1; }
grep -q 'scripts/project-context-map.ps1' "$ROOT/framework/01-core/00-core-system.md" || { echo "Core missing project context map rule" >&2; exit 1; }
grep -q 'Identify the owning folder before creating a file' "$ROOT/framework/26-decision-graphs/file-folder-decision-graph.md" || { echo "File-folder graph missing owner rule" >&2; exit 1; }
grep -q 'Determine whether the behavior will be reused in multiple places' "$ROOT/framework/26-decision-graphs/file-folder-decision-graph.md" || { echo "File-folder graph missing shared-owner decision" >&2; exit 1; }
grep -q 'shared/common/library owner' "$ROOT/framework/26-decision-graphs/file-folder-decision-graph.md" || { echo "File-folder graph missing shared owner rule" >&2; exit 1; }
grep -q 'standalone file becomes a hidden subsystem' "$ROOT/framework/26-decision-graphs/file-folder-decision-graph.md" || { echo "File-folder graph missing hidden-subsystem rule" >&2; exit 1; }
grep -q 'oversized mixed files' "$ROOT/framework/26-decision-graphs/file-folder-decision-graph.md" || { echo "File-folder graph missing oversized-file rule" >&2; exit 1; }
grep -q 'SSR, SSG, streaming' "$ROOT/framework/10-frontend/00-frontend-engineering.md" || { echo "Frontend missing SSR evaluation rule" >&2; exit 1; }
grep -q 'Split large frontend files' "$ROOT/framework/10-frontend/00-frontend-engineering.md" || { echo "Frontend missing large-file split rule" >&2; exit 1; }
grep -q 'Prevent over-rendering' "$ROOT/framework/10-frontend/00-frontend-engineering.md" || { echo "Frontend missing over-render rule" >&2; exit 1; }
grep -q 'Animations must use transform and opacity' "$ROOT/framework/10-frontend/00-frontend-engineering.md" || { echo "Frontend missing animation performance rule" >&2; exit 1; }
grep -q 'pagination, filtering, sorting, aggregation, projection' "$ROOT/framework/11-backend/00-backend-engineering.md" || { echo "Backend missing server-side data-shaping rule" >&2; exit 1; }
grep -q 'Split large backend files' "$ROOT/framework/11-backend/00-backend-engineering.md" || { echo "Backend missing large-file split rule" >&2; exit 1; }
grep -q 'Prevent backend-driven over-render' "$ROOT/framework/11-backend/00-backend-engineering.md" || { echo "Backend missing over-render rule" >&2; exit 1; }
grep -q 'publish minimal scoped events' "$ROOT/framework/11-backend/00-backend-engineering.md" || { echo "Backend missing scoped-events rule" >&2; exit 1; }
grep -q 'limited to the requested feature' "$ROOT/framework/27-quality-gates/code-quality-gate.md" || { echo "Code quality gate missing requested-scope rule" >&2; exit 1; }
grep -q 'Unrelated pre-existing errors were not repaired' "$ROOT/framework/27-quality-gates/code-quality-gate.md" || { echo "Code quality gate missing unrelated-error rule" >&2; exit 1; }
grep -q 'Reusable behavior was placed in the existing shared/common/library owner' "$ROOT/framework/27-quality-gates/code-quality-gate.md" || { echo "Code quality gate missing shared-placement rule" >&2; exit 1; }
grep -q 'Existing shared components, tokens, services' "$ROOT/framework/27-quality-gates/code-quality-gate.md" || { echo "Code quality gate missing shared-search rule" >&2; exit 1; }
grep -q 'Reusable UI must live in the appropriate shared design-system owner' "$ROOT/framework/46-design-system-consistency-reuse/00-unified-design-system-architecture.md" || { echo "Reuse pack missing shared UI owner rule" >&2; exit 1; }
grep -q 'Before creating custom UI' "$ROOT/framework/46-design-system-consistency-reuse/00-unified-design-system-architecture.md" || { echo "Reuse pack missing design-system-first rule" >&2; exit 1; }
grep -q 'Place repeated hooks, stores, formatters, validators' "$ROOT/framework/46-design-system-consistency-reuse/06-shared-frontend-services-validation-api.md" || { echo "Reuse pack missing shared services rule" >&2; exit 1; }
grep -q 'Feature code should import shared services' "$ROOT/framework/46-design-system-consistency-reuse/06-shared-frontend-services-validation-api.md" || { echo "Reuse pack missing import services rule" >&2; exit 1; }
grep -q "Answer the user's direct question first" "$ROOT/framework/03-runtime/10-final-response-format.md" || { echo "Final response format missing direct-answer rule" >&2; exit 1; }
grep -q 'Do not claim "perfect"' "$ROOT/framework/03-runtime/10-final-response-format.md" || { echo "Final response format missing overclaim rule" >&2; exit 1; }
[ -f "$ROOT/scripts/install-design-engineering-skills.ps1" ] || { echo "Missing design skills installer" >&2; exit 1; }
[ -f "$ROOT/scripts/install-design-engineering-skills.sh" ] || { echo "Missing Unix design skills installer" >&2; exit 1; }
[ -f "$ROOT/framework/58-agent-model-orchestration/00-agent-model-orchestration-system.md" ] || { echo "Missing agent orchestration system" >&2; exit 1; }
[ -f "$ROOT/framework/27-quality-gates/31-agent-model-routing-gate.md" ] || { echo "Missing agent routing gate" >&2; exit 1; }
[ -f "$ROOT/scripts/select-agent-route.ps1" ] || { echo "Missing agent route selector" >&2; exit 1; }
[ -f "$ROOT/scripts/select-agent-route.sh" ] || { echo "Missing Unix agent route selector" >&2; exit 1; }
[ -f "$ROOT/scripts/test-agent-route.ps1" ] || { echo "Missing agent route tests" >&2; exit 1; }
[ -f "$ROOT/scripts/test-agent-route.sh" ] || { echo "Missing Unix agent route tests" >&2; exit 1; }
[ -f "$ROOT/scripts/test-browser-control-contract.ps1" ] || { echo "Missing browser control contract tests" >&2; exit 1; }
[ -f "$ROOT/scripts/test-browser-control-contract.sh" ] || { echo "Missing Unix browser control contract tests" >&2; exit 1; }
sh "$ROOT/scripts/test-browser-control-contract.sh"
[ -f "$ROOT/scripts/test-skeleton-loading-contract.ps1" ] || { echo "Missing skeleton loading contract tests" >&2; exit 1; }
[ -f "$ROOT/scripts/test-skeleton-loading-contract.sh" ] || { echo "Missing Unix skeleton loading contract tests" >&2; exit 1; }
sh "$ROOT/scripts/test-skeleton-loading-contract.sh"
[ -f "$ROOT/scripts/test-delivery-continuation-contract.ps1" ] || { echo "Missing delivery continuation contract tests" >&2; exit 1; }
[ -f "$ROOT/scripts/validate-goal-lifecycle.ps1" ] || { echo "Missing goal lifecycle validator" >&2; exit 1; }
[ -f "$ROOT/scripts/validate-goal-lifecycle.sh" ] || { echo "Missing Unix goal lifecycle validator" >&2; exit 1; }
[ -f "$ROOT/scripts/test-goal-lifecycle.ps1" ] || { echo "Missing goal lifecycle tests" >&2; exit 1; }
[ -f "$ROOT/scripts/test-goal-lifecycle.sh" ] || { echo "Missing Unix goal lifecycle tests" >&2; exit 1; }
! grep -Rqi 'must stop the task' "$ROOT/framework/49-engineering-guardian" || { echo "Engineering Guardian still stops implementation work" >&2; exit 1; }
grep -q 'BLOCKED_ALLOWED' "$ROOT/framework/01-core/14-delivery-continuation-policy.md" || { echo "Missing canonical goal transition contract" >&2; exit 1; }
[ -f "$ROOT/scripts/test-runtime-hardening.ps1" ] || { echo "Missing runtime hardening tests" >&2; exit 1; }
[ -f "$ROOT/scripts/test-installers.ps1" ] || { echo "Missing installer tests" >&2; exit 1; }
[ -f "$ROOT/scripts/test-cleanup-workspace.ps1" ] || { echo "Missing cleanup tests" >&2; exit 1; }
[ -f "$ROOT/scripts/test-documentation-links.ps1" ] || { echo "Missing documentation link tests" >&2; exit 1; }
[ -f "$ROOT/scripts/test-release-consistency.ps1" ] || { echo "Missing Windows release consistency tests" >&2; exit 1; }
[ -f "$ROOT/scripts/test-release-consistency.sh" ] || { echo "Missing Unix release consistency tests" >&2; exit 1; }
[ -f "$ROOT/scripts/project-technology-inventory.mjs" ] || { echo "Missing project technology inventory" >&2; exit 1; }
[ -f "$ROOT/scripts/test-project-modernization-contract.ps1" ] || { echo "Missing Windows project modernization tests" >&2; exit 1; }
[ -f "$ROOT/scripts/test-project-modernization-contract.sh" ] || { echo "Missing Unix project modernization tests" >&2; exit 1; }
[ -f "$ROOT/scripts/test-continuous-assurance-failure-propagation.ps1" ] || { echo "Missing assurance failure-propagation tests" >&2; exit 1; }
[ -f "$ROOT/scripts/test-quality-gate-selection.ps1" ] || { echo "Missing quality-gate selector tests" >&2; exit 1; }
[ -f "$ROOT/scripts/write-active-state.sh" ] || { echo "Missing Unix active-state writer" >&2; exit 1; }
"$ROOT/scripts/test-agent-route.sh" >/dev/null || { echo "Unix agent route tests failed" >&2; exit 1; }
"$ROOT/scripts/test-goal-lifecycle.sh" >/dev/null || { echo "Unix goal lifecycle tests failed" >&2; exit 1; }
sh "$ROOT/scripts/test-release-consistency.sh" "$ROOT" >/dev/null || { echo "Unix release consistency tests failed" >&2; exit 1; }
sh "$ROOT/scripts/test-project-modernization-contract.sh" "$ROOT" >/dev/null || { echo "Unix project modernization tests failed" >&2; exit 1; }
route="$("$ROOT/scripts/select-agent-route.sh" --risk-floor Privacy)"
printf '%s' "$route" | grep -q '"tier":"T4"' || { echo "Unix agent route risk floor failed" >&2; exit 1; }
printf '%s' "$route" | grep -q '"spawnAgents":false' || { echo "Unix agent route delegation guard failed" >&2; exit 1; }
version="$(sed -n 's/.*version: \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' "$ROOT/VERSION.md" | head -n 1)"
grep -q "\"version\": \"$version\"" "$ROOT/release-manifest.json" || { echo "Version and release manifest do not match" >&2; exit 1; }
if grep -q '\[0-9\.\]\*' "$ROOT/scripts/ueef-audit.sh"; then echo "Unix audit uses an unsafe broad version pattern" >&2; exit 1; fi
grep -q 'UEEF skill icon' "$ROOT/assets/ueef-skill-icon.svg" || { echo "Skill icon missing accessible title" >&2; exit 1; }
grep -q '"icon": "assets/ueef-skill-icon.svg"' "$ROOT/assets/ueef-display.json" || { echo "Display metadata missing icon path" >&2; exit 1; }
grep -q 'Project Context Map' "$ROOT/scripts/project-context-map.sh" || { echo "Unix project context map missing header" >&2; exit 1; }
sh "$ROOT/scripts/project-context-map.sh" "$ROOT" 5 >/dev/null || { echo "Unix project context map failed" >&2; exit 1; }
for f in framework/50-environment-bootstrap/README.md framework/50-environment-bootstrap/INDEX.md framework/50-environment-bootstrap/00-environment-bootstrap.md framework/50-environment-bootstrap/01-profile-selection.md framework/50-environment-bootstrap/02-core-profile.md framework/50-environment-bootstrap/03-frontend-profile.md framework/50-environment-bootstrap/04-backend-profile.md framework/50-environment-bootstrap/05-database-profile.md framework/50-environment-bootstrap/06-uiux-profile.md framework/50-environment-bootstrap/07-devops-profile.md framework/50-environment-bootstrap/08-ai-profile.md framework/50-environment-bootstrap/09-optional-profile.md framework/50-environment-bootstrap/10-dependency-levels.md framework/50-environment-bootstrap/11-detection-and-installation.md framework/50-environment-bootstrap/12-mcp-detection.md framework/50-environment-bootstrap/13-runtime-bootstrap-sequence.md; do
  [ -f "$ROOT/$f" ] || { echo "Missing $f" >&2; exit 1; }
done
echo "UEEF validation passed"
echo "Markdown file count: $count"
echo "Framework pack count: $(find "$ROOT/framework" -maxdepth 1 -type d -name '[0-9][0-9]-*' | wc -l)"
echo "Total file count: $(find "$ROOT" -type f | wc -l)"
