$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$requiredRoot = @("README.md","INSTALL.md","QUICK_START.md","VERSION.md","CHANGELOG.md","LICENSE","CONTRIBUTING.md","CODE_OF_CONDUCT.md","SECURITY.md","ROADMAP.md","BUILD_PROGRESS.md")
$missing = @()
foreach ($f in $requiredRoot) { if (!(Test-Path (Join-Path $Root $f))) { $missing += $f } }
$requiredDirs = @("framework","scripts","docs","examples","tools")
foreach ($d in $requiredDirs) { if (!(Test-Path (Join-Path $Root $d))) { $missing += $d } }
$requiredAcceptance = @(
  "docs/token-efficiency.md",
  "framework/01-core/00-boot-loader.md",
  "examples/generic-ai/deploy-runtime-check.md",
  "examples/generic-ai/database-runtime-check.md",
  "examples/generic-ai/backend-api-runtime-check.md",
  "examples/generic-ai/frontend-task-runtime-check.md",
  "docs/runtime-hardening.md",
  "scripts/write-active-state.ps1",
  "scripts/select-quality-gates.ps1",
  "scripts/check-runtime-drift.ps1",
  "scripts/sync-runtime.ps1",
  "examples/generic-ai/runtime-check-example.md",
  "framework/27-quality-gates/16-ueef-activation-gate.md",
  "framework/01-core/10-runtime-activation-proof.md",
  "docs/verify-ueef-is-active.md",
  "scripts/ueef-status.sh",
  "scripts/ueef-status.ps1",
  "framework/38-templates/feature-implementation-template.md",
  "framework/38-templates/component-creation-template.md",
  "framework/38-templates/api-creation-template.md",
  "framework/38-templates/database-change-template.md",
  "framework/38-templates/adr-template.md",
  "framework/38-templates/pull-request-template.md",
  "framework/38-templates/security-review-template.md",
  "framework/38-templates/performance-review-template.md",
  "framework/38-templates/risk-assessment-template.md",
  "framework/38-templates/incident-report-template.md",
  "framework/38-templates/engineering-review-template.md",
  "framework/26-decision-graphs/component-decision-graph.md",
  "framework/26-decision-graphs/file-folder-decision-graph.md",
  "framework/26-decision-graphs/dependency-decision-graph.md",
  "framework/26-decision-graphs/api-decision-graph.md",
  "framework/26-decision-graphs/database-decision-graph.md",
  "framework/26-decision-graphs/state-management-decision-graph.md",
  "framework/26-decision-graphs/caching-decision-graph.md",
  "framework/26-decision-graphs/security-decision-graph.md",
  "framework/26-decision-graphs/performance-decision-graph.md",
  "framework/26-decision-graphs/refactoring-decision-graph.md",
  "framework/26-decision-graphs/ui-decision-graph.md",
  "framework/26-decision-graphs/architecture-decision-graph.md",
  "framework/27-quality-gates/requirements-gate.md",
  "framework/27-quality-gates/architecture-gate.md",
  "framework/27-quality-gates/code-quality-gate.md",
  "framework/27-quality-gates/security-gate.md",
  "framework/27-quality-gates/performance-gate.md",
  "framework/27-quality-gates/database-gate.md",
  "framework/27-quality-gates/api-gate.md",
  "framework/27-quality-gates/ui-gate.md",
  "framework/27-quality-gates/ux-gate.md",
  "framework/27-quality-gates/accessibility-gate.md",
  "framework/27-quality-gates/testing-gate.md",
  "framework/27-quality-gates/documentation-gate.md",
  "framework/27-quality-gates/production-gate.md",
  "framework/27-quality-gates/enterprise-gate.md",
  "framework/27-quality-gates/final-gate.md",
  "framework/28-scorecards/engineering-scorecard.md",
  "framework/28-scorecards/architecture-scorecard.md",
  "framework/28-scorecards/code-quality-scorecard.md",
  "framework/28-scorecards/security-scorecard.md",
  "framework/28-scorecards/performance-scorecard.md",
  "framework/28-scorecards/scalability-scorecard.md",
  "framework/28-scorecards/maintainability-scorecard.md",
  "framework/28-scorecards/ui-scorecard.md",
  "framework/28-scorecards/ux-scorecard.md",
  "framework/28-scorecards/accessibility-scorecard.md",
  "framework/28-scorecards/production-readiness-scorecard.md",
  "framework/28-scorecards/enterprise-readiness-scorecard.md",
  "framework/28-scorecards/final-review-scorecard.md"
)
foreach ($f in $requiredAcceptance) {
  if (!(Test-Path (Join-Path $Root $f))) { $missing += $f }
}
$packs = Get-ChildItem (Join-Path $Root "framework") -Directory
foreach ($p in $packs) {
  if (!(Test-Path (Join-Path $p.FullName "README.md"))) { $missing += "$($p.Name)/README.md" }
  if (!(Test-Path (Join-Path $p.FullName "INDEX.md"))) { $missing += "$($p.Name)/INDEX.md" }
}
if ($missing.Count) { throw "Missing required items: $($missing -join ', ')" }
$md = Get-ChildItem $Root -Filter *.md -Recurse
if ($md.Count -lt 160) { throw "Markdown count below minimum: $($md.Count)" }
$empty = $md | Where-Object { $_.Length -eq 0 }
if ($empty) { throw "Empty Markdown files: $($empty.FullName -join ', ')" }
$weak = Select-String -Path $md.FullName -Pattern 'TODO only|lorem ipsum|placeholder only|TBD only' -CaseSensitive:$false -ErrorAction SilentlyContinue
if ($weak) { throw "Placeholder-like marker found: $($weak[0].Path):$($weak[0].LineNumber)" }
$scriptNames = @("install-codex.ps1","install-codex.sh","install-cursor.ps1","install-cursor.sh","install-generic.ps1","install-generic.sh","validate-framework.ps1","validate-framework.sh","backup-existing-rules.ps1","backup-existing-rules.sh","detect-agent.ps1","detect-agent.sh")
foreach ($s in $scriptNames) { if (!(Test-Path (Join-Path $Root "scripts/$s"))) { throw "Missing script $s" } }
$master = Join-Path $Root "framework/MASTER_INDEX.md"
if (!(Test-Path $master)) { throw "Missing framework/MASTER_INDEX.md" }
$masterText = Get-Content $master -Raw
if ($masterText -notmatch "00-foundation" -or $masterText -notmatch "27-quality-gates" -or $masterText -notmatch "38-templates") { throw "Master index missing expected pack references" }
Write-Host "UEEF validation passed"
Write-Host "Markdown file count: $($md.Count)"
Write-Host "Framework pack count: $($packs.Count)"
Write-Host "Total file count: $((Get-ChildItem $Root -File -Recurse).Count)"
