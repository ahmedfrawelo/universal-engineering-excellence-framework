param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$SkipNestedTests,
  [switch]$Quiet
)
$ErrorActionPreference = "Stop"
if ($env:UEEF_QUIET_VALIDATION -eq '1') { $Quiet = $true }

function Invoke-NodeChecked {
  param([Parameter(Mandatory)][string[]]$Arguments)
  & node @Arguments
  if ($LASTEXITCODE -ne 0) { throw "Node validation failed with exit code ${LASTEXITCODE}: $($Arguments -join ' ')" }
}
$requiredRoot = @("README.md","INSTALL.md","QUICK_START.md","VERSION.md","CHANGELOG.md","LICENSE","CONTRIBUTING.md","CODE_OF_CONDUCT.md","SECURITY.md","ROADMAP.md","BUILD_PROGRESS.md","UEEF-LOADER.md")
$missing = @()
foreach ($f in $requiredRoot) { if (!(Test-Path (Join-Path $Root $f))) { $missing += $f } }
$requiredDirs = @("framework","scripts","docs","examples","tools","config","engines")
foreach ($d in $requiredDirs) { if (!(Test-Path (Join-Path $Root $d))) { $missing += $d } }
$manifestPath = Join-Path $Root "release-manifest.json"
if (!(Test-Path -LiteralPath $manifestPath)) { $missing += "release-manifest.json" }
$manifest = if (Test-Path -LiteralPath $manifestPath) { Get-Content $manifestPath -Raw | ConvertFrom-Json } else { $null }
$requiredAcceptance = @(
  "docs/token-efficiency.md",
  "framework/DOMAIN_MAP.md",
  "framework/_domains/README.md",
  "framework/_domains/INVENTORY.md",
  "framework/01-core/00-boot-loader.md",
  "framework/01-core/13-autonomy-and-confirmation-policy.md",
  "framework/01-core/14-delivery-continuation-policy.md",
  "examples/generic-ai/deploy-runtime-check.md",
  "examples/generic-ai/database-runtime-check.md",
  "examples/generic-ai/backend-api-runtime-check.md",
  "examples/generic-ai/frontend-task-runtime-check.md",
  "docs/runtime-hardening.md",
  "scripts/write-active-state.ps1",
  "scripts/select-quality-gates.ps1",
  "scripts/select-frontend-route.mjs",
  "scripts/select-frontend-route.ps1",
  "scripts/select-frontend-route.sh",
  "scripts/test-frontend-routing.mjs",
  "scripts/test-design-production-workflow.mjs",
  "scripts/test-frontend-routing.ps1",
  "scripts/check-runtime-drift.ps1",
  "scripts/sync-runtime.ps1",
  "scripts/managed-enforcement.ps1",
  "scripts/codex-hooks/ueef-codex-hook.mjs",
  "scripts/codex-hooks/record-ueef-route.mjs",
  "scripts/codex-hooks/ueef-hook-common.mjs",
  "scripts/test-managed-enforcement.ps1",
  "config/codex-enforcement-policy.json",
  "docs/architecture/decisions/0001-managed-codex-enforcement.md",
  "scripts/new-spec-workflow.ps1",
  "scripts/validate-spec-workflow.ps1",
  "scripts/test-spec-workflow.ps1",
  "scripts/get-capability-health.ps1",
  "scripts/test-capability-health.ps1",
  "scripts/get-ueef-health.ps1",
  "scripts/test-ueef-health.ps1",
  "scripts/select-capability-profile.ps1",
  "scripts/get-ueef-task-classification.ps1",
  "scripts/test-task-classification.ps1",
  "scripts/test-capability-profile.ps1",
  "scripts/get-ueef-task-preflight.ps1",
  "scripts/ueef-doctor.ps1",
  "scripts/test-ueef-doctor.ps1",
  "scripts/test-ueef-task-preflight.ps1",
  "scripts/get-diff-impact.ps1",
  "scripts/test-diff-impact.ps1",
  "scripts/write-project-memory.ps1",
  "scripts/get-project-memory.ps1",
  "scripts/test-project-memory.ps1",
  "scripts/resolve-team-policy.ps1",
  "scripts/test-team-policy.ps1",
  "config/team-policy-profiles.json",
  "scripts/export-ueef-evidence.ps1",
  "scripts/test-evidence-export.ps1",
  "scripts/get-task-budget-advice.ps1",
  "scripts/test-task-budget-advice.ps1",
  "scripts/record-learning-loop.ps1",
  "scripts/test-learning-loop.ps1",
  "scripts/get-workspace-boundaries.ps1",
  "scripts/test-workspace-boundaries.ps1",
  "scripts/new-refactor-recipe.ps1",
  "scripts/test-refactor-recipe.ps1",
  "scripts/get-onboarding-preview.ps1",
  "scripts/test-onboarding-preview.ps1",
  "config/assistant-adapters.json",
  "scripts/get-assistant-adapters.ps1",
  "scripts/test-assistant-adapters.ps1",
  "scripts/measure-assurance.ps1",
  "scripts/test-assurance-performance.ps1",
  "config/assurance-budgets.json",
  "config/model-routing-policy.json",
  "config/capability-registry.json",
  "config/preferred-skills.json",
  "config/preferred-capabilities.json",
  "config/enforcement-registry.json",
  "scripts/install-preferred-skills.ps1",
  "scripts/install-preferred-skills.sh",
  "scripts/reconcile-preferred-capabilities.ps1",
  "scripts/test-preferred-capabilities.ps1",
  "scripts/validate-task-evidence.ps1",
  "scripts/new-task-evidence.ps1",
  "scripts/test-new-task-evidence.ps1",
  "scripts/test-enforcement-coverage.ps1",
  "scripts/test-task-evidence-semantics.ps1",
  "scripts/get-file-organization-report.ps1",
  "scripts/test-file-organization-report.ps1",
  "scripts/get-architecture-report.ps1",
  "scripts/test-architecture-report.ps1",
  "scripts/get-remote-debugging-readiness.ps1",
  "scripts/test-remote-debugging-readiness.ps1",
  "config/file-organization-policy.json",
  "config/architecture-policy.json",
  "config/browser-emergency-fallback.json",
  "scripts/test-preferred-skills.mjs",
  "examples/generic-ai/runtime-check-example.md",
  "framework/12-delivery-quality/04-quality-gates/16-ueef-activation-gate.md",
  "framework/12-delivery-quality/04-quality-gates/19-theme-responsive-interaction-security-performance-gate.md",
  "framework/12-delivery-quality/05-scorecards/15-theme-responsive-interaction-security-performance-scorecard.md",
  "framework/14-decision/02-graphs/19-theme-architecture-decision-graph.md",
  "framework/14-decision/02-graphs/20-responsive-component-decision-graph.md",
  "framework/14-decision/02-graphs/21-overlay-behavior-decision-graph.md",
  "framework/14-decision/02-graphs/22-security-hardening-decision-graph.md",
  "framework/14-decision/02-graphs/23-performance-optimization-decision-graph.md",
  "framework/12-delivery-quality/06-checklists/23-theme-review-checklist.md",
  "framework/12-delivery-quality/06-checklists/24-dark-mode-review-checklist.md",
  "framework/12-delivery-quality/06-checklists/25-responsive-first-checklist.md",
  "framework/12-delivery-quality/06-checklists/26-dropdown-panel-overlay-checklist.md",
  "framework/12-delivery-quality/06-checklists/27-security-hardening-checklist.md",
  "framework/12-delivery-quality/06-checklists/28-extreme-performance-checklist.md",
  "framework/21-framework-resources/01-templates/16-theme-definition-template.md",
  "framework/21-framework-resources/01-templates/17-responsive-component-contract-template.md",
  "framework/21-framework-resources/01-templates/18-overlay-interaction-contract-template.md",
  "framework/21-framework-resources/01-templates/19-security-review-report-template.md",
  "framework/21-framework-resources/01-templates/20-performance-budget-template.md",
  "release-manifest.json",
  "docs/releases/v1.1.0.md",
  "framework/12-delivery-quality/04-quality-gates/20-design-governance-gate.md",
  "framework/12-delivery-quality/05-scorecards/16-design-governance-scorecard.md",
  "framework/12-delivery-quality/06-checklists/29-design-governance-checklist.md",
  "framework/21-framework-resources/01-templates/21-design-governance-review-template.md",
  "docs/releases/v1.2.0.md",
  "framework/12-delivery-quality/04-quality-gates/21-engineering-guardian-gate.md",
  "framework/12-delivery-quality/05-scorecards/17-engineering-health-scorecard.md",
  "framework/12-delivery-quality/06-checklists/30-engineering-guardian-checklist.md",
  "docs/releases/v1.3.0.md",
  "scripts/environment-bootstrap.ps1",
  "scripts/environment-bootstrap.sh",
  "framework/12-delivery-quality/04-quality-gates/22-environment-bootstrap-gate.md",
  "framework/12-delivery-quality/05-scorecards/18-environment-readiness-scorecard.md",
  "framework/12-delivery-quality/06-checklists/31-environment-bootstrap-checklist.md",
  "docs/releases/v1.4.0.md",
  "framework/12-delivery-quality/04-quality-gates/23-browser-session-control-gate.md",
  "framework/12-delivery-quality/06-checklists/32-browser-session-control-checklist.md",
  "framework/18-runtime-operations/02-browser-session-control/09-platform-authorized-chrome-control.md",
  "framework/18-runtime-operations/02-browser-session-control/10-window-state-preservation.md",
  "framework/18-runtime-operations/02-browser-session-control/11-control-surface-selection.md",
  "framework/18-runtime-operations/02-browser-session-control/12-cross-session-evidence-handoff.md",
  "framework/18-runtime-operations/02-browser-session-control/13-user-facing-recovery-protocol.md",
  "framework/18-runtime-operations/02-browser-session-control/14-automatic-tab-ownership-recovery.md",
  "framework/18-runtime-operations/02-browser-session-control/15-chrome-control-readiness.md",
  "docs/releases/v1.5.0.md",
  "scripts/cleanup-workspace.ps1",
  "scripts/cleanup-workspace.sh",
  "framework/12-delivery-quality/04-quality-gates/24-workspace-hygiene-gate.md",
  "framework/12-delivery-quality/06-checklists/33-workspace-hygiene-checklist.md",
  "framework/18-runtime-operations/03-workspace-hygiene/README.md",
  "framework/18-runtime-operations/03-workspace-hygiene/INDEX.md",
  "framework/18-runtime-operations/03-workspace-hygiene/00-workspace-hygiene-system.md",
  "framework/12-delivery-quality/04-quality-gates/25-skeleton-loading-gate.md",
  "framework/12-delivery-quality/06-checklists/34-skeleton-loading-checklist.md",
  "framework/21-framework-resources/01-templates/22-skeleton-loading-contract-template.md",
  "framework/17-product-platform/02-skeleton-loading/README.md",
  "framework/17-product-platform/02-skeleton-loading/INDEX.md",
  "framework/17-product-platform/02-skeleton-loading/00-skeleton-loading-system.md",
  "framework/17-product-platform/02-skeleton-loading/07-render-timing-and-flicker-control.md",
  "framework/17-product-platform/02-skeleton-loading/08-ssr-hydration-and-streaming.md",
  "framework/17-product-platform/02-skeleton-loading/09-shared-skeleton-api-and-registry.md",
  "scripts/extract-design-system.mjs",
  "scripts/recommend-design-system.mjs",
  "framework/12-delivery-quality/04-quality-gates/26-design-intelligence-gate.md",
  "framework/12-delivery-quality/06-checklists/35-design-intelligence-checklist.md",
  "framework/21-framework-resources/01-templates/23-design-recommendation-template.md",
  "framework/16-design-system/04-intelligence/README.md",
  "framework/16-design-system/04-intelligence/INDEX.md",
  "framework/16-design-system/04-intelligence/00-design-intelligence-system.md",
  "scripts/ueef-audit.ps1",
  "scripts/ueef-audit.sh",
  "framework/12-delivery-quality/04-quality-gates/27-continuous-assurance-gate.md",
  "framework/12-delivery-quality/06-checklists/36-continuous-assurance-checklist.md",
  "framework/18-runtime-operations/04-continuous-assurance/README.md",
  "framework/18-runtime-operations/04-continuous-assurance/INDEX.md",
  "framework/18-runtime-operations/04-continuous-assurance/00-assurance-system.md",
  "framework/12-delivery-quality/04-quality-gates/28-data-grid-platform-gate.md",
  "framework/12-delivery-quality/06-checklists/37-data-grid-platform-checklist.md",
  "framework/21-framework-resources/01-templates/24-data-grid-contract-template.md",
  "framework/21-framework-resources/01-templates/25-realtime-refresh-contract-template.md",
  "framework/17-product-platform/03-data-grid-platform/README.md",
  "framework/17-product-platform/03-data-grid-platform/INDEX.md",
  "framework/17-product-platform/03-data-grid-platform/00-data-grid-platform-system.md",
  "framework/17-product-platform/03-data-grid-platform/12-live-refresh-hardening.md",
  "framework/12-delivery-quality/04-quality-gates/29-application-shell-design-gate.md",
  "framework/12-delivery-quality/06-checklists/38-application-shell-design-checklist.md",
  "framework/21-framework-resources/01-templates/26-application-shell-baseline-template.md",
  "framework/17-product-platform/04-application-shell-design/README.md",
  "framework/17-product-platform/04-application-shell-design/INDEX.md",
  "framework/17-product-platform/04-application-shell-design/00-application-shell-system.md",
  "framework/12-delivery-quality/04-quality-gates/30-visual-composition-gate.md",
  "framework/12-delivery-quality/06-checklists/39-visual-composition-checklist.md",
  "framework/21-framework-resources/01-templates/27-visual-composition-review-template.md",
  "framework/12-delivery-quality/04-quality-gates/31-agent-model-routing-gate.md",
  "framework/12-delivery-quality/06-checklists/40-agent-model-routing-checklist.md",
  "framework/21-framework-resources/01-templates/28-agent-routing-decision-template.md",
  "framework/21-framework-resources/01-templates/33-fresh-review-evidence-template.json",
  "framework/19-agent-workflow/01-model-orchestration/README.md",
  "framework/19-agent-workflow/01-model-orchestration/INDEX.md",
  "framework/19-agent-workflow/01-model-orchestration/00-agent-model-orchestration-system.md",
  "framework/19-agent-workflow/01-model-orchestration/06-fresh-context-review-protocol.md",
  "docs/specifications/fresh-review-protocol.md",
  "docs/third-party/sol-advisor-attribution.md",
  "framework/19-agent-workflow/02-skill-invocation-protocol/README.md",
  "framework/19-agent-workflow/02-skill-invocation-protocol/INDEX.md",
  "framework/19-agent-workflow/02-skill-invocation-protocol/00-skill-invocation-protocol-system.md",
  "framework/19-agent-workflow/02-skill-invocation-protocol/01-skill-discovery-and-routing.md",
  "framework/19-agent-workflow/02-skill-invocation-protocol/02-red-flag-detection.md",
  "framework/19-agent-workflow/02-skill-invocation-protocol/03-spec-plan-execution-chain.md",
  "framework/19-agent-workflow/02-skill-invocation-protocol/04-tdd-and-evidence-loop.md",
  "framework/19-agent-workflow/02-skill-invocation-protocol/05-subagent-review-chain.md",
  "framework/19-agent-workflow/02-skill-invocation-protocol/06-skill-authoring-quality.md",
  "framework/12-delivery-quality/04-quality-gates/32-skill-invocation-protocol-gate.md",
  "framework/12-delivery-quality/06-checklists/41-skill-invocation-protocol-checklist.md",
  "docs/third-party/superpowers-attribution.md",
  "framework/19-agent-workflow/03-spec-driven-development/README.md",
  "framework/19-agent-workflow/03-spec-driven-development/INDEX.md",
  "framework/19-agent-workflow/03-spec-driven-development/00-spec-driven-development-system.md",
  "framework/19-agent-workflow/03-spec-driven-development/01-constitution-and-principles.md",
  "framework/19-agent-workflow/03-spec-driven-development/02-specification-artifact.md",
  "framework/19-agent-workflow/03-spec-driven-development/03-clarification-and-ambiguity.md",
  "framework/19-agent-workflow/03-spec-driven-development/04-technical-plan-translation.md",
  "framework/19-agent-workflow/03-spec-driven-development/05-task-breakdown-and-parallelization.md",
  "framework/19-agent-workflow/03-spec-driven-development/06-consistency-analysis-and-checklists.md",
  "framework/19-agent-workflow/03-spec-driven-development/07-implementation-and-convergence.md",
  "framework/19-agent-workflow/03-spec-driven-development/08-extension-preset-bundle-governance.md",
  "framework/19-agent-workflow/03-spec-driven-development/09-third-party-attribution.md",
  "framework/12-delivery-quality/04-quality-gates/33-spec-driven-development-gate.md",
  "framework/12-delivery-quality/06-checklists/42-spec-driven-development-checklist.md",
  "framework/21-framework-resources/01-templates/29-spec-driven-development-template.md",
  "docs/third-party/spec-kit-attribution.md",
  "framework/20-repository-evolution/03-repository-intelligence/README.md",
  "framework/20-repository-evolution/03-repository-intelligence/INDEX.md",
  "framework/20-repository-evolution/03-repository-intelligence/00-repository-intelligence-system.md",
  "framework/10-frontend/02-production-design/README.md",
  "framework/10-frontend/02-production-design/INDEX.md",
  "framework/10-frontend/02-production-design/00-frontend-design-production-system.md",
  "framework/10-frontend/02-production-design/01-design-contract.md",
  "framework/10-frontend/02-production-design/02-routing-and-skill-roles.md",
  "framework/10-frontend/02-production-design/03-styleseed-quality-loop.md",
  "framework/10-frontend/02-production-design/04-penpot-mcp-workflow.md",
  "framework/10-frontend/02-production-design/05-execution-sequence.md",
  "framework/10-frontend/02-production-design/THIRD-PARTY-NOTICES.md",
  "framework/12-delivery-quality/04-quality-gates/35-frontend-design-production-gate.md",
  "framework/21-framework-resources/01-templates/31-design-contract-template.md",
  "framework/21-framework-resources/01-templates/32-frontend-execution-evidence-template.json",
  "scripts/frontend-design-production-route-lib.mjs",
  "scripts/validate-frontend-execution-evidence.mjs",
  "scripts/repository-intelligence.ps1",
  "scripts/repository-intelligence.sh",
  "scripts/test-repository-intelligence.ps1",
  "scripts/test-repository-intelligence.sh",
  "scripts/verify-repository-intelligence-engine.mjs",
  "config/repository-intelligence-policy.json",
  "docs/architecture/decisions/0002-native-repository-intelligence.md",
  "engines/repository-intelligence/UEEF-UPSTREAM.json",
  "engines/repository-intelligence/MODIFICATIONS.md",
  "engines/repository-intelligence/UPSTREAM-FILES.json",
  "engines/repository-intelligence/LICENSE",
  "engines/repository-intelligence/LICENSE-MIT",
  "engines/repository-intelligence/NOTICE",
  "scripts/select-agent-route.ps1",
  "scripts/select-agent-route.sh",
  "scripts/test-agent-route.ps1",
  "scripts/resolve-model-route.mjs",
  "scripts/update-codex-thread-settings.mjs",
  "scripts/test-model-routing-policy.mjs",
  "scripts/test-codex-thread-settings-update.mjs",
  "docs/specifications/model-route-execution.md",
  "scripts/test-agent-route.sh",
  "scripts/validate-fresh-review-evidence.ps1",
  "scripts/test-fresh-review-protocol.ps1",
  "scripts/test-browser-control-contract.ps1",
  "scripts/test-skeleton-loading-contract.ps1",
  "scripts/test-skeleton-loading-contract.sh",
  "scripts/repair-chrome-tab-ownership.ps1",
  "scripts/test-repair-chrome-tab-ownership.ps1",
  "scripts/test-delivery-continuation-contract.ps1",
  "scripts/test-intent-fidelity-contract.ps1",
  "scripts/validate-goal-lifecycle.ps1",
  "scripts/validate-completion-audit.ps1",
  "scripts/validate-completion-audit.mjs",
  "scripts/validate-completion-audit.sh",
  "scripts/get-local-service-readiness.ps1",
  "scripts/test-local-service-readiness.ps1",
  "scripts/test-completion-audit.ps1",
  "scripts/validate-goal-lifecycle.sh",
  "scripts/test-goal-lifecycle.ps1",
  "scripts/test-goal-lifecycle.sh",
  "scripts/test-performance-forensics.ps1",
  "scripts/test-runtime-hardening.ps1",
  "scripts/test-runtime-drift-performance.ps1",
  "scripts/test-environment-bootstrap.ps1",
  "scripts/test-installers.ps1",
  "scripts/test-cleanup-workspace.ps1",
  "scripts/test-documentation-links.ps1",
  "scripts/test-documentation-links.sh",
  "scripts/test-documentation-links.mjs",
  "scripts/generate-framework-indexes.mjs",
  "scripts/test-framework-indexes.mjs",
  "scripts/test-release-consistency.ps1",
  "scripts/test-release-consistency.sh",
  "scripts/publish-github-release.ps1",
  "scripts/test-project-context-map.ps1",
  "scripts/test-project-context-map.sh",
  "scripts/project-technology-inventory.mjs",
  "scripts/test-project-modernization-contract.ps1",
  "scripts/test-project-modernization-contract.sh",
  "scripts/test-continuous-assurance-failure-propagation.ps1",
  "scripts/test-quality-gate-selection.ps1",
  "scripts/write-active-state.sh",
  "scripts/active-state.mjs",
  "scripts/runtime-file-policy.ps1",
  "scripts/runtime-file-policy.mjs",
  "scripts/copy-release-files.mjs",
  "scripts/check-runtime-drift.mjs",
  "scripts/install-runtime.ps1",
  "scripts/install-runtime.sh",
  "scripts/test-script-syntax.ps1",
  "scripts/test-script-syntax.sh",
  "scripts/test-ueef-status.sh",
  "scripts/test-module-specificity.mjs",
  "docs/releases/v2.6.0.md",
  "docs/releases/v2.7.0.md",
  "docs/releases/v2.7.1.md",
  "docs/releases/v2.8.0.md",
  "docs/releases/v2.8.1.md",
  "docs/releases/v2.8.2.md",
  "docs/releases/v2.8.3.md",
  "docs/releases/v2.8.4.md",
  "docs/releases/v2.8.5.md",
  "docs/releases/v2.8.6.md",
  "docs/releases/v2.8.7.md",
  "docs/releases/v2.8.8.md",
  "docs/releases/v2.8.9.md",
  "docs/releases/v2.8.10.md",
  "docs/releases/v2.8.11.md",
  "docs/releases/v2.8.12.md",
  "docs/releases/v2.8.13.md",
  "docs/releases/v2.8.14.md",
  "docs/releases/v2.8.15.md",
  "docs/releases/v2.8.16.md",
  "docs/releases/v2.8.17.md",
  "docs/releases/v2.8.18.md",
  "docs/releases/v2.8.19.md",
  "docs/releases/v2.8.20.md",
  "docs/releases/v2.8.21.md",
  "docs/releases/v2.8.22.md",
  "docs/releases/v2.8.23.md",
  "docs/releases/v2.8.24.md",
  "docs/releases/v2.9.0.md",
  "docs/releases/v2.9.1.md",
  "docs/releases/v2.9.2.md",
  "docs/releases/v2.10.0.md",
  "docs/specifications/application-evolution-runtime-performance.md",
  "framework/16-design-system/02-theme-responsive-interaction-security-performance/50-application-lazy-loading.md",
  "framework/16-design-system/02-theme-responsive-interaction-security-performance/51-global-live-refresh.md",
  "framework/20-repository-evolution/01-project-modernization/README.md",
  "framework/20-repository-evolution/01-project-modernization/INDEX.md",
  "framework/20-repository-evolution/01-project-modernization/00-project-modernization-system.md",
  "framework/20-repository-evolution/01-project-modernization/01-discovery-and-baseline.md",
  "framework/20-repository-evolution/01-project-modernization/02-behavior-preserving-refactoring.md",
  "framework/20-repository-evolution/01-project-modernization/03-dead-and-obsolete-code.md",
  "framework/20-repository-evolution/01-project-modernization/04-architecture-and-data-modernization.md",
  "framework/20-repository-evolution/01-project-modernization/05-technology-currency-assessment.md",
  "framework/20-repository-evolution/01-project-modernization/06-upgrade-decision-and-execution.md",
  "framework/20-repository-evolution/01-project-modernization/07-performance-freshness-and-lazy-loading.md",
  "framework/20-repository-evolution/01-project-modernization/08-verification-rollout-and-rollback.md",
  "framework/12-delivery-quality/04-quality-gates/34-project-modernization-and-runtime-gate.md",
  "framework/12-delivery-quality/06-checklists/43-project-modernization-and-runtime-checklist.md",
  "framework/21-framework-resources/01-templates/30-project-modernization-plan-template.md",
  "scripts/install-design-engineering-skills.ps1",
  "scripts/install-design-engineering-skills.sh",
  "scripts/install-open-design-skills.ps1",
  "scripts/install-open-design-skills.sh",
  "assets/ueef-display.json",
  "assets/ueef-skill-icon.svg",
  "scripts/project-context-map.ps1",
  "scripts/project-context-map.sh",
  "framework/01-core/10-runtime-activation-proof.md",
  "docs/verify-ueef-is-active.md",
  "scripts/ueef-status.sh",
  "scripts/ueef-status.ps1",
  "framework/21-framework-resources/01-templates/feature-implementation-template.md",
  "framework/21-framework-resources/01-templates/component-creation-template.md",
  "framework/21-framework-resources/01-templates/api-creation-template.md",
  "framework/21-framework-resources/01-templates/database-change-template.md",
  "framework/21-framework-resources/01-templates/adr-template.md",
  "framework/21-framework-resources/01-templates/pull-request-template.md",
  "framework/21-framework-resources/01-templates/security-review-template.md",
  "framework/21-framework-resources/01-templates/performance-review-template.md",
  "framework/21-framework-resources/01-templates/risk-assessment-template.md",
  "framework/21-framework-resources/01-templates/incident-report-template.md",
  "framework/21-framework-resources/01-templates/engineering-review-template.md",
  "framework/14-decision/02-graphs/component-decision-graph.md",
  "framework/14-decision/02-graphs/file-folder-decision-graph.md",
  "framework/14-decision/02-graphs/dependency-decision-graph.md",
  "framework/14-decision/02-graphs/api-decision-graph.md",
  "framework/14-decision/02-graphs/database-decision-graph.md",
  "framework/14-decision/02-graphs/state-management-decision-graph.md",
  "framework/14-decision/02-graphs/caching-decision-graph.md",
  "framework/14-decision/02-graphs/security-decision-graph.md",
  "framework/14-decision/02-graphs/performance-decision-graph.md",
  "framework/14-decision/02-graphs/refactoring-decision-graph.md",
  "framework/14-decision/02-graphs/ui-decision-graph.md",
  "framework/14-decision/02-graphs/architecture-decision-graph.md",
  "framework/12-delivery-quality/04-quality-gates/requirements-gate.md",
  "framework/12-delivery-quality/04-quality-gates/architecture-gate.md",
  "framework/12-delivery-quality/04-quality-gates/code-quality-gate.md",
  "framework/12-delivery-quality/04-quality-gates/security-gate.md",
  "framework/12-delivery-quality/04-quality-gates/performance-gate.md",
  "framework/12-delivery-quality/04-quality-gates/database-gate.md",
  "framework/12-delivery-quality/04-quality-gates/api-gate.md",
  "framework/12-delivery-quality/04-quality-gates/ui-gate.md",
  "framework/12-delivery-quality/04-quality-gates/ux-gate.md",
  "framework/12-delivery-quality/04-quality-gates/accessibility-gate.md",
  "framework/12-delivery-quality/04-quality-gates/testing-gate.md",
  "framework/12-delivery-quality/04-quality-gates/documentation-gate.md",
  "framework/12-delivery-quality/04-quality-gates/production-gate.md",
  "framework/12-delivery-quality/04-quality-gates/enterprise-gate.md",
  "framework/12-delivery-quality/04-quality-gates/final-gate.md",
  "framework/12-delivery-quality/05-scorecards/engineering-scorecard.md",
  "framework/12-delivery-quality/05-scorecards/architecture-scorecard.md",
  "framework/12-delivery-quality/05-scorecards/code-quality-scorecard.md",
  "framework/12-delivery-quality/05-scorecards/security-scorecard.md",
  "framework/12-delivery-quality/05-scorecards/performance-scorecard.md",
  "framework/12-delivery-quality/05-scorecards/scalability-scorecard.md",
  "framework/12-delivery-quality/05-scorecards/maintainability-scorecard.md",
  "framework/12-delivery-quality/05-scorecards/ui-scorecard.md",
  "framework/12-delivery-quality/05-scorecards/ux-scorecard.md",
  "framework/12-delivery-quality/05-scorecards/accessibility-scorecard.md",
  "framework/12-delivery-quality/05-scorecards/production-readiness-scorecard.md",
  "framework/12-delivery-quality/05-scorecards/enterprise-readiness-scorecard.md",
  "framework/12-delivery-quality/05-scorecards/final-review-scorecard.md"
)
foreach ($f in $requiredAcceptance) {
  if (!(Test-Path (Join-Path $Root $f))) { $missing += $f }
}
$packs = Get-ChildItem (Join-Path $Root "framework") -Directory | Where-Object { $_.Name -match '^[0-9][0-9]-' }
foreach ($p in $packs) {
  if (!(Test-Path (Join-Path $p.FullName "README.md"))) { $missing += "$($p.Name)/README.md" }
  if (!(Test-Path (Join-Path $p.FullName "INDEX.md"))) { $missing += "$($p.Name)/INDEX.md" }
}
if ($missing.Count) { throw "Missing required items: $($missing -join ', ')" }
$engineGeneratedPattern = '[\\/]engines[\\/]repository-intelligence[\\/](?:\.venv|build|graphifyy\.egg-info|__pycache__|\.pytest_cache|\.hypothesis|\.ruff_cache|\.mypy_cache)(?:[\\/]|$)'
$md = Get-ChildItem $Root -Filter *.md -Recurse | Where-Object {
  $_.FullName -notmatch '[\\/]\.ueef[\\/]' -and $_.FullName -notmatch $engineGeneratedPattern
}
$minimumMarkdownFiles = if ($manifest -and $manifest.minimumMarkdownFiles) { [int]$manifest.minimumMarkdownFiles } else { 160 }
if ($md.Count -lt $minimumMarkdownFiles) { throw "Markdown count below minimum: $($md.Count) < $minimumMarkdownFiles" }
$trackedMarkdownFiles = if ($manifest -and $manifest.trackedMarkdownFiles) { [int]$manifest.trackedMarkdownFiles } else { 0 }
if ($trackedMarkdownFiles -le 0 -or $md.Count -ne $trackedMarkdownFiles) { throw "Markdown inventory mismatch: actual $($md.Count), manifest $trackedMarkdownFiles" }
$empty = $md | Where-Object { $_.Length -eq 0 }
if ($empty) { throw "Empty Markdown files: $($empty.FullName -join ', ')" }
$weak = Select-String -Path $md.FullName -Pattern 'TODO only|lorem ipsum|placeholder only|TBD only' -CaseSensitive:$false -ErrorAction SilentlyContinue
if ($weak) { throw "Placeholder-like marker found: $($weak[0].Path):$($weak[0].LineNumber)" }
$mojibake = Select-String -Path $md.FullName -Pattern '\u00E2\u20AC' -CaseSensitive -ErrorAction SilentlyContinue
if ($mojibake) { throw "Mojibake marker found: $($mojibake[0].Path):$($mojibake[0].LineNumber)" }
$scriptNames = @("install-codex.ps1","install-codex.sh","install-cursor.ps1","install-cursor.sh","install-generic.ps1","install-generic.sh","validate-framework.ps1","validate-framework.sh","backup-existing-rules.ps1","backup-existing-rules.sh","detect-agent.ps1","detect-agent.sh")
foreach ($s in $scriptNames) { if (!(Test-Path (Join-Path $Root "scripts/$s"))) { throw "Missing script $s" } }
$master = Join-Path $Root "framework/MASTER_INDEX.md"
if (!(Test-Path $master)) { throw "Missing framework/MASTER_INDEX.md" }
$masterText = Get-Content $master -Raw
if ($masterText -notmatch "00-foundation" -or $masterText -notmatch "12-delivery-quality/04-quality-gates" -or $masterText -notmatch "21-framework-resources/01-templates") { throw "Master index missing expected pack references" }
if ($masterText -notmatch "DOMAIN_MAP.md") { throw "Master index missing domain map routing reference" }
$domainMapText = Get-Content (Join-Path $Root "framework/DOMAIN_MAP.md") -Raw
if ($domainMapText -notmatch "_domains/README.md") { throw "Domain map missing physical domain folder reference" }
$domainInventoryText = Get-Content (Join-Path $Root "framework/_domains/INVENTORY.md") -Raw
foreach ($pack in $packs.Name) {
  $matches = [regex]::Matches($domainInventoryText, [regex]::Escape("[``$pack``]"))
  if ($matches.Count -ne 1) { throw "Domain inventory must list $pack exactly once; found $($matches.Count)" }
}
$requiredLinks = @("17-product-platform/01-identity-access-application-models","16-design-system/01-consistency-reuse","16-design-system/02-theme-responsive-interaction-security-performance","16-design-system/03-governance","12-delivery-quality/08-engineering-guardian","18-runtime-operations/01-environment-bootstrap","18-runtime-operations/02-browser-session-control","18-runtime-operations/03-workspace-hygiene","17-product-platform/02-skeleton-loading","16-design-system/04-intelligence","18-runtime-operations/04-continuous-assurance","17-product-platform/03-data-grid-platform","17-product-platform/04-application-shell-design","19-agent-workflow/01-model-orchestration","19-agent-workflow/02-skill-invocation-protocol","19-agent-workflow/03-spec-driven-development")
foreach ($link in $requiredLinks) { if ($masterText -notmatch [regex]::Escape($link)) { throw "Master index missing $link" } }
$environmentModules = @("README.md","INDEX.md","00-environment-bootstrap.md","01-profile-selection.md","02-core-profile.md","03-frontend-profile.md","04-backend-profile.md","05-database-profile.md","06-uiux-profile.md","07-devops-profile.md","08-ai-profile.md","09-optional-profile.md","10-dependency-levels.md","11-detection-and-installation.md","12-mcp-detection.md","13-runtime-bootstrap-sequence.md")
foreach ($file in $environmentModules) { if (!(Test-Path (Join-Path $Root "framework/18-runtime-operations/01-environment-bootstrap/$file"))) { throw "Environment Bootstrap missing module: $file" } }
$bootstrapScript = Get-Content (Join-Path $Root "scripts/environment-bootstrap.ps1") -Raw
foreach ($term in @("Mandatory","Recommended","Optional","ui-ux-pro-max","impeccable","typeui-fundamentals","frontend-design","design-brief","emil-design-eng","review-animations","improve-animations","animation-vocabulary","apple-design","Overall READY","Overall BLOCKED","package","csproj","schema","Dockerfile")) { if ($bootstrapScript -notmatch [regex]::Escape($term)) { throw "Bootstrap script missing required behavior: $term" } }
$coreText = Get-Content (Join-Path $Root "framework/01-core/00-core-system.md") -Raw
foreach ($term in @("existing theme","light, dark, and system","responsive","overlay","Security and performance","component registry","governed design tokens","Quick", "Build", "Audit", "Do not stack skills solely","typeui-fundamentals","Place every new file under an existing owned feature","Do not solve a multi-file feature by creating a standalone-file system","Keep files small enough to review and maintain","Answer the user's actual question first","server-side filtering, sorting, pagination, aggregation","evaluate SSR, SSG, streaming","Prevent over-rendering on both frontend and backend-driven UI paths","Animations must be smooth","Stay inside the user's requested task scope","Task Scope Discipline","Shared-first rule","Before creating custom UI or custom behavior","Large Project Reuse Requirements","Record the reuse decision","scripts/project-context-map.ps1")) { if ($coreText -notmatch [regex]::Escape($term)) { throw "Core System missing required rule: $term" } }
$fileFolderText = Get-Content (Join-Path $Root "framework/14-decision/02-graphs/file-folder-decision-graph.md") -Raw
foreach ($term in @("Determine whether the behavior will be reused in multiple places","shared/common/library owner","standalone file becomes a hidden subsystem","oversized mixed files")) { if ($fileFolderText -notmatch [regex]::Escape($term)) { throw "File-folder decision graph missing required rule: $term" } }
$frontendText = Get-Content (Join-Path $Root "framework/10-frontend/01-engineering/00-frontend-engineering.md") -Raw
foreach ($term in @("SSR, SSG, streaming","Split large frontend files","Prevent over-rendering","Animations must use transform and opacity")) { if ($frontendText -notmatch [regex]::Escape($term)) { throw "Frontend pack missing required rule: $term" } }
$backendText = Get-Content (Join-Path $Root "framework/11-server-side/02-backend/00-backend-engineering.md") -Raw
foreach ($term in @("pagination, filtering, sorting, aggregation, projection","Split large backend files","latency budgets","Prevent backend-driven over-render","publish minimal scoped events")) { if ($backendText -notmatch [regex]::Escape($term)) { throw "Backend pack missing required rule: $term" } }
$finalResponseText = Get-Content (Join-Path $Root "framework/03-runtime/10-final-response-format.md") -Raw
foreach ($term in @("Answer the user's direct question first","Separate verified facts from assumptions",'Do not claim "perfect"',"trust the renderer for ordinary mixed-language text","never wrap a full sentence or status block in inline code","copyable file paths")) { if ($finalResponseText -notmatch [regex]::Escape($term)) { throw "Final response format missing required rule: $term" } }
$codeGateText = Get-Content (Join-Path $Root "framework/12-delivery-quality/04-quality-gates/code-quality-gate.md") -Raw
foreach ($term in @("limited to the requested feature","Unrelated pre-existing errors were not repaired","opportunistic fixes outside the requested scope","Reusable behavior was placed in the existing shared/common/library owner","Existing shared components, tokens, services")) { if ($codeGateText -notmatch [regex]::Escape($term)) { throw "Code quality gate missing required rule: $term" } }
$reuseText = (Get-Content (Join-Path $Root "framework/16-design-system/01-consistency-reuse/00-unified-design-system-architecture.md") -Raw) + "`n" + (Get-Content (Join-Path $Root "framework/16-design-system/01-consistency-reuse/06-shared-frontend-services-validation-api.md") -Raw)
foreach ($term in @("Reusable UI must live in the appropriate shared design-system owner","Before creating custom UI","Place repeated hooks, stores, formatters, validators","Feature code should import shared services")) { if ($reuseText -notmatch [regex]::Escape($term)) { throw "Design system reuse pack missing required rule: $term" } }
$runtimeText = Get-Content (Join-Path $Root "framework/03-runtime/00-runtime-sequence.md") -Raw
foreach ($term in @("Existing theme inspected:","Theme tokens found:","Responsive system found:","Overlay system found:","UI UX Pro Max checked:","Design engineering skill route:","Specialist motion skills checked:")) { if ($runtimeText -notmatch [regex]::Escape($term)) { throw "Runtime sequence missing preflight field: $term" } }
$designTerms = @("Existing project UI searched:","Component registry searched:","Pattern library searched:","Reuse or extension decision:","Token families identified:")
foreach ($term in $designTerms) { if ($runtimeText -notmatch [regex]::Escape($term)) { throw "Runtime sequence missing design governance field: $term" } }
$guardianTerms = @("Affected baseline recorded:","Regression monitors selected:","Self-criticism completed:","Final Guardian Gate:")
foreach ($term in $guardianTerms) { if ($runtimeText -notmatch [regex]::Escape($term)) { throw "Runtime sequence missing guardian field: $term" } }
$bootstrapTerms = @("Environment Ready:","Profiles Loaded:","Mandatory Dependencies:","Recommended Dependencies:","Optional Dependencies:","Installation Performed:")
foreach ($term in $bootstrapTerms) { if ($runtimeText -notmatch [regex]::Escape($term)) { throw "Runtime sequence missing bootstrap field: $term" } }
$browserTerms = @("User-owned browser/profile verified:","Chrome readiness flow completed:","Extension/tab-claim authorization granted:","Chrome-family binding selected explicitly:","Existing window/profile/session proven with user.openTabs():","Dedicated task tab created in same Chrome window/profile/session:","User working tab preserved:","Exact dedicated-tab object claimed:","Existing window state preserved:","Target tab and domain verified:","Control provenance:","Control channel:","Failure stage/reason/next recorded:","Automatic ownership repair run when needed:","Verification evidence:","New window/browser/profile/session/context/panel/internal surface created:","Banner classification:","Signed-in state verified when required:","Browser session gate:")
foreach ($term in $browserTerms) { if ($runtimeText -notmatch [regex]::Escape($term)) { throw "Runtime sequence missing browser session field: $term" } }
$skeletonTerms = @("Skeleton system selected:","Existing loading pattern searched:","Skeleton reused or updated:","State matrix defined:","Skeleton parity verified:","Layout shift checked:","Skeleton timing policy selected:","Delayed reveal verified:","Minimum visible duration verified:","SSR/hydration parity verified:","Shared skeleton API contract verified:","Skeleton family owner and canonical public import verified:","Cancellation and refresh behavior verified:","Skeleton gate:")
foreach ($term in $skeletonTerms) { if ($runtimeText -notmatch [regex]::Escape($term)) { throw "Runtime sequence missing skeleton field: $term" } }
$designTerms = @("Design source of truth identified:","Design extraction run:","Fonts and assets classified:","Colors and theme mappings classified:","Icons and stroke system classified:","Missing roles and recommendations documented:","Design intelligence gate:")
foreach ($term in $designTerms) { if ($runtimeText -notmatch [regex]::Escape($term)) { throw "Runtime sequence missing design intelligence field: $term" } }
$assuranceTerms = @("Continuous assurance audit run:","Security hygiene checked:","Generated artifacts checked:","Script syntax checked:","Release/runtime parity checked:","Residual risks recorded:","Continuous assurance gate:")
foreach ($term in $assuranceTerms) { if ($runtimeText -notmatch [regex]::Escape($term)) { throw "Runtime sequence missing assurance field: $term" } }
$gridTerms = @("Existing table baseline inspected:","Query contract defined:","Server capabilities allowlisted:","Pagination/filter/sort/aggregate semantics verified:","Backend/API/database contract verified:","Performance budget verified:","Realtime/refresh contract verified:","Live refresh no-reload proof verified:","Realtime security and burst-performance proof verified:","Advanced grid capabilities verified:","Production data delivery controls verified:","Data grid platform gate:")
foreach ($term in $gridTerms) { if ($runtimeText -notmatch [regex]::Escape($term)) { throw "Runtime sequence missing data-grid field: $term" } }
$shellTerms = @("Shell baseline extracted:","Navigation/header contracts verified:","Shell motion/responsive/accessibility verified:","Shell visual/performance gate:")
foreach ($term in $shellTerms) { if ($runtimeText -notmatch [regex]::Escape($term)) { throw "Runtime sequence missing shell field: $term" } }
$visualTerms = @("First-viewport composition reviewed:","Density and responsive composition verified:","Visual evidence gate:")
foreach ($term in $visualTerms) { if ($runtimeText -notmatch [regex]::Escape($term)) { throw "Runtime sequence missing visual-composition field: $term" } }
$agentTerms = @("Task complexity score:","Risk floor:","Agent route tier:","Model capability class:","Agent topology:","Delegation benefit verified:","Independent workstreams:","Agent capability available:","Named model availability verified:","Fresh review mode:","Fresh review evidence and unchanged post-review diff verified when required:","Agent model routing gate:")
foreach ($term in $agentTerms) { if ($runtimeText -notmatch [regex]::Escape($term)) { throw "Runtime sequence missing agent-routing field: $term" } }
$skillProtocolTerms = @("Skill candidates:","Selected skill chain:","Skipped skills and reason:","Red flags checked:","Skill protocol gate:")
foreach ($term in $skillProtocolTerms) { if ($runtimeText -notmatch [regex]::Escape($term)) { throw "Runtime sequence missing skill protocol field: $term" } }
$specDrivenTerms = @("Spec-driven applicability:","Specification artifact:","Open ambiguities:","Requirements-to-plan trace:","Task breakdown trace:","Consistency analysis:","Convergence evidence:","Spec-driven gate:")
foreach ($term in $specDrivenTerms) { if ($runtimeText -notmatch [regex]::Escape($term)) { throw "Runtime sequence missing spec-driven field: $term" } }
if (!$SkipNestedTests) {
  & (Join-Path $Root "scripts/test-spec-workflow.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-capability-health.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-capability-profile.ps1") | Out-Null
  Invoke-NodeChecked @((Join-Path $Root "scripts/test-preferred-skills.mjs"), $Root) | Out-Null
  & (Join-Path $Root "scripts/test-preferred-capabilities.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-enforcement-coverage.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-new-task-evidence.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-task-evidence-semantics.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-file-organization-report.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-architecture-report.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-remote-debugging-readiness.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-task-classification.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-frontend-routing.ps1") | Out-Null
  Invoke-NodeChecked @((Join-Path $Root "scripts/test-design-production-workflow.mjs")) | Out-Null
  & (Join-Path $Root "scripts/test-ueef-task-preflight.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-ueef-doctor.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-diff-impact.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-project-memory.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-team-policy.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-evidence-export.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-task-budget-advice.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-learning-loop.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-workspace-boundaries.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-refactor-recipe.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-onboarding-preview.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-assistant-adapters.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-assurance-performance.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-agent-route.ps1") | Out-Null
  Invoke-NodeChecked @((Join-Path $Root "scripts/test-model-routing-policy.mjs")) | Out-Null
  & (Join-Path $Root "scripts/test-fresh-review-protocol.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-browser-control-contract.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-skeleton-loading-contract.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-delivery-continuation-contract.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-intent-fidelity-contract.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-goal-lifecycle.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-managed-enforcement.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-completion-audit.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-local-service-readiness.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-performance-forensics.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-environment-bootstrap.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-quality-gate-selection.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-documentation-links.ps1") | Out-Null
  Invoke-NodeChecked @((Join-Path $Root "scripts/test-framework-indexes.mjs"), $Root) | Out-Null
  Invoke-NodeChecked @((Join-Path $Root "scripts/test-module-specificity.mjs"), $Root) | Out-Null
  & (Join-Path $Root "scripts/test-release-consistency.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-runtime-drift-performance.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-project-context-map.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-repository-intelligence.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-project-modernization-contract.ps1") | Out-Null
  & (Join-Path $Root "scripts/test-continuous-assurance-failure-propagation.ps1") | Out-Null
  & (Join-Path $Root "scripts/project-context-map.ps1") -Path $Root -MaxItems 5 | Out-Null
}
$syncText = Get-Content (Join-Path $Root "scripts/sync-runtime.ps1") -Raw
foreach ($term in @("Unsafe agent name","runtimeRootPrefix","Agent = `$Agent","RequireManagedEnforcement","environment-bootstrap")) {
  if ($syncText -notmatch [regex]::Escape($term)) { throw "Runtime sync missing hardening contract: $term" }
}
$version = (Get-Content (Join-Path $Root "VERSION.md") -Raw | Select-String -Pattern '\b\d+\.\d+\.\d+\b' -AllMatches).Matches[0].Value
if ($manifest.version -ne $version) { throw "Version and release manifest do not match" }
if ($manifest.releaseDate -notmatch '^\d{4}-\d{2}-\d{2}$') { throw "Manifest releaseDate must use yyyy-MM-dd" }
try { [datetime]::ParseExact([string]$manifest.releaseDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) | Out-Null } catch { throw "Manifest releaseDate is not a valid date" }
if ([int]$manifest.frameworkPacks -ne $packs.Count) { throw "Manifest framework pack count does not match the repository" }
if (!(Test-Path -LiteralPath (Join-Path $Root $manifest.releaseNotes))) { throw "Manifest release notes do not exist: $($manifest.releaseNotes)" }
$releaseNotesText = Get-Content -LiteralPath (Join-Path $Root $manifest.releaseNotes) -Raw
if ($releaseNotesText -notmatch [regex]::Escape($manifest.version)) { throw "Manifest release notes do not mention version $($manifest.version)" }
foreach ($entrypoint in $manifest.entrypoints.psobject.Properties) {
  if (!(Test-Path -LiteralPath (Join-Path $Root ([string]$entrypoint.Value)))) { throw "Manifest entrypoint does not exist: $($entrypoint.Name)=$($entrypoint.Value)" }
}
foreach ($asset in $manifest.assets.psobject.Properties) {
  if (!(Test-Path -LiteralPath (Join-Path $Root ([string]$asset.Value)))) { throw "Manifest asset does not exist: $($asset.Name)=$($asset.Value)" }
}
foreach ($pack in $manifest.expansionPacks) { if (!(Test-Path -LiteralPath (Join-Path $Root $pack))) { throw "Manifest expansion pack does not exist: $pack" } }
$publishReleaseText = Get-Content -LiteralPath (Join-Path $Root 'scripts/publish-github-release.ps1') -Raw
foreach ($term in @('git-credential-manager','gh release create','Release notes file is empty','Wait-ForSuccessfulValidation','Validate UEEF','Never print tokens')) {
  if ($term -eq 'Never print tokens') { continue }
  if ($publishReleaseText -notmatch [regex]::Escape($term)) { throw "GitHub release publisher missing required behavior: $term" }
}
$releaseIntegrityText = Get-Content -LiteralPath (Join-Path $Root 'framework/18-runtime-operations/04-continuous-assurance/04-release-and-installation-integrity.md') -Raw
foreach ($term in @('publish-github-release.ps1','Validate UEEF','exact release commit','Git Credential Manager','do not start a browser device-login flow','Never print tokens')) {
  if ($releaseIntegrityText -notmatch [regex]::Escape($term)) { throw "Release integrity guidance missing GitHub credential fallback: $term" }
}
if ((Get-Content (Join-Path $Root "UEEF-LOADER.md") -Raw) -notmatch [regex]::Escape("not a reason to suspend execution")) { throw "Loader missing delivery continuation rule" }
if ((Get-Content (Join-Path $Root "UEEF-LOADER.md") -Raw) -notmatch [regex]::Escape("Status-loop guard")) { throw "Loader missing status-loop guard" }
if ((Get-Content (Join-Path $Root "framework/01-core/14-delivery-continuation-policy.md") -Raw) -notmatch [regex]::Escape("Repeated status phrasing is a control-flow failure")) { throw "Delivery continuation policy missing status-loop guard" }
if ((Get-Content (Join-Path $Root "UEEF-LOADER.md") -Raw) -notmatch "19-agent-workflow/01-model-orchestration|pack 58") { throw "Loader missing agent model routing rule" }
$syncText = Get-Content (Join-Path $Root "scripts/sync-runtime.ps1") -Raw
foreach ($term in @("Agent and model routing:","Design engineering skill routing:","emil-design-eng","review-animations","improve-animations","animation-vocabulary","apple-design","not a reason to suspend execution","Local command autonomy:")) {
  if ($syncText -notmatch [regex]::Escape($term)) { throw "Runtime generator missing global loader policy: $term" }
}
foreach ($term in @("File, folder, and size discipline:","Backend and frontend performance:","Response quality:","Task scope discipline:","Prevent over-rendering end to end","Animations must be smooth","SSR, SSG, streaming","standalone-file system","Reusable behavior, UI, validation","Before creating custom UI or behavior","Large-project reuse:","Discover module boundaries","project-context-map","Skill/display metadata","Skill/display icon")) {
  if ($syncText -notmatch [regex]::Escape($term)) { throw "Runtime generator missing new operating policy: $term" }
}
foreach ($term in @("Arabic or other RTL prose","trust the renderer for ordinary mixed-language text","never wrap a full sentence or status block in inline code","Do not insert hidden bidirectional control characters","four-item localized list","never join route fields with |")) {
  if ($syncText -notmatch [regex]::Escape($term)) { throw "Runtime generator missing mixed-direction response policy: $term" }
}
$responsePolicyText = (Get-Content (Join-Path $Root "UEEF-LOADER.md") -Raw) + "`n" + (Get-Content (Join-Path $Root "framework/01-core/00-core-system.md") -Raw) + "`n" + $finalResponseText + "`n" + $syncText
if ($responsePolicyText -match 'Intent: <requested outcome> \| Tier: <T0-T4>|every inline English word.*must be isolated') { throw "Obsolete mixed-direction response formatting remains active" }
foreach ($term in @("Skill invocation protocol:","skill chain","red flags","TDD or an equivalent evidence loop")) {
  if ($syncText -notmatch [regex]::Escape($term)) { throw "Runtime generator missing skill protocol policy: $term" }
}
foreach ($term in @("Missing screenshot evidence","pCloud screenshot delay","not a valid BLOCKED condition","screenshot is pending")) {
  if ($syncText -notmatch [regex]::Escape($term)) { throw "Runtime generator missing visual-blocker policy: $term" }
}
foreach ($term in @("Chrome readiness flow","normal authorization","not proof that Chrome is unavailable","run scripts/repair-chrome-tab-ownership.ps1","CHROME_EXTERNALLY_UNAVAILABLE")) {
  if ($syncText -notmatch [regex]::Escape($term)) { throw "Runtime generator missing Chrome readiness policy: $term" }
}
foreach ($term in @("Spec-driven development:","specification the source of truth","technical plan and traceable tasks","Check consistency across specification, plan, tasks, code, tests, and final claims")) {
  if ($syncText -notmatch [regex]::Escape($term)) { throw "Runtime generator missing spec-driven policy: $term" }
}
foreach ($term in @("Reconcile mutable remote state without page reload","eager, lazy, preload, prefetch, stream, or defer","Inventory runtimes, dependencies, and upgrade opportunities only","Broad legacy refactoring requires")) {
  if ($syncText -notmatch [regex]::Escape($term)) { throw "Runtime generator missing modernization policy: $term" }
}
$modernizationRuntimeTerms = @("Repository and behavior baseline captured:","Technology inventory and support evidence captured:","Refactoring and dead-code reachability proof verified:","Live refresh no-page-reload and context-preservation proof verified:","Project modernization and runtime gate:")
foreach ($term in $modernizationRuntimeTerms) { if ($runtimeText -notmatch [regex]::Escape($term)) { throw "Runtime sequence missing modernization field: $term" } }
$displayMetadata = Get-Content (Join-Path $Root "assets/ueef-display.json") -Raw | ConvertFrom-Json
if ($displayMetadata.icon -ne "assets/ueef-skill-icon.svg" -or $displayMetadata.displayName -ne "UEEF") { throw "Display metadata does not reference the UEEF icon correctly" }
$iconText = Get-Content (Join-Path $Root "assets/ueef-skill-icon.svg") -Raw
foreach ($term in @("<svg","role=""img""","UEEF skill icon")) { if ($iconText -notmatch [regex]::Escape($term)) { throw "Skill icon missing required SVG term: $term" } }
$projectMapText = Get-Content (Join-Path $Root "scripts/project-context-map.ps1") -Raw
foreach ($term in @("Project Context Map","Shared candidates","Generated/output candidates","Repository intelligence:")) { if ($projectMapText -notmatch [regex]::Escape($term)) { throw "Project context map missing required behavior: $term" } }
$repositoryIntelligenceText = (Get-Content (Join-Path $Root "scripts/repository-intelligence.ps1") -Raw) + "`n" + (Get-Content (Join-Path $Root "framework/20-repository-evolution/03-repository-intelligence/00-repository-intelligence-system.md") -Raw)
foreach ($term in @("build", "query", "path", "explain", "affected", "status", "doctor", "local", "offline", "EXTRACTED", "INFERRED", "AMBIGUOUS")) { if ($repositoryIntelligenceText -notmatch [regex]::Escape($term)) { throw "Repository intelligence contract missing required term: $term" } }
$statusAndTestText = (Get-Content (Join-Path $Root "scripts/ueef-status.ps1") -Raw) + "`n" + (Get-Content (Join-Path $Root "scripts/test-runtime-hardening.ps1") -Raw)
foreach ($term in @("Runtime drift:","Runtime drift did not invalidate ACTIVE status","sourceRepositoryPath")) { if ($statusAndTestText -notmatch [regex]::Escape($term)) { throw "Runtime status/drift coverage missing: $term" } }
$selectorText = (Get-Content (Join-Path $Root "scripts/select-quality-gates.ps1") -Raw) + "`n" + (Get-Content (Join-Path $Root "scripts/select-frontend-route.mjs") -Raw)
foreach ($term in @("motion","animation","emil-design-eng","Specialist skill route:")) { if ($selectorText -notmatch [regex]::Escape($term)) { throw "Quality gate selector missing motion routing: $term" } }
foreach ($term in @("FrontendMode","frontendMode","skillRoutes","Quick","Build","Audit","01-frontend-task-modes","25-skeleton-loading-gate")) { if ($selectorText -notmatch [regex]::Escape($term)) { throw "Quality gate selector missing proportional frontend routing: $term" } }
foreach ($term in @("superpowers","skill invocation","32-skill-invocation-protocol-gate","19-agent-workflow/02-skill-invocation-protocol")) { if ($selectorText -notmatch [regex]::Escape($term)) { throw "Quality gate selector missing skill protocol routing: $term" } }
foreach ($term in @("spec kit","spec-driven","33-spec-driven-development-gate","19-agent-workflow/03-spec-driven-development")) { if ($selectorText -notmatch [regex]::Escape($term)) { throw "Quality gate selector missing spec-driven routing: $term" } }
foreach ($term in @("refactor","dependency upgrade","34-project-modernization-and-runtime-gate","20-repository-evolution/01-project-modernization","global-live-refresh","application-lazy-loading")) { if ($selectorText -notmatch [regex]::Escape($term)) { throw "Quality gate selector missing modernization routing: $term" } }
$attributionText = Get-Content (Join-Path $Root "docs/third-party/superpowers-attribution.md") -Raw
foreach ($term in @("Superpowers","MIT License","6fd4507659784c351abbd2bc264c7162cfd386dc","https://github.com/TheACJ/superpower")) { if ($attributionText -notmatch [regex]::Escape($term)) { throw "Superpowers attribution missing required term: $term" } }
$specAttributionText = Get-Content (Join-Path $Root "docs/third-party/spec-kit-attribution.md") -Raw
foreach ($term in @("Spec Kit","MIT License","fd101d531eaec8a1e709db2f37632bc93b6ce4d6","https://github.com/github/spec-kit","https://github.github.io/spec-kit/")) { if ($specAttributionText -notmatch [regex]::Escape($term)) { throw "Spec Kit attribution missing required term: $term" } }
$unixAudit = Get-Content (Join-Path $Root "scripts/ueef-audit.sh") -Raw
if ($unixAudit -match '\[0-9\.\]\*') { throw "Unix audit uses an unsafe broad version pattern" }
if (!$Quiet) {
Write-Host "UEEF validation passed"
Write-Host "Markdown file count: $($md.Count)"
Write-Host "Framework pack count: $($packs.Count)"
$totalFileCount = @(Get-ChildItem $Root -File -Recurse -Force | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }).Count
Write-Host "Total file count: $totalFileCount"
}
