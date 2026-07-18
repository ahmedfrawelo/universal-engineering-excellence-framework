param(
  [Parameter(Mandatory=$true)][string]$Task
)
$ErrorActionPreference = "Stop"
$text = $Task.ToLowerInvariant()
$modules = New-Object System.Collections.Generic.List[string]
$gates = New-Object System.Collections.Generic.List[string]
$uiRequired = $false
$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Add-Unique($list, [string[]]$items) {
  foreach ($item in $items) {
    if (!$list.Contains($item)) { [void]$list.Add($item) }
  }
}

function Assert-ExistingFrameworkPaths([string[]]$paths) {
  foreach ($path in $paths) {
    $fullPath = Join-Path $repositoryRoot $path
    if (!(Test-Path -LiteralPath $fullPath -PathType Leaf)) {
      throw "Selected framework path does not exist: $path"
    }
  }
}

Add-Unique $modules @(
  "framework/01-core/00-boot-loader.md",
  "framework/01-core/00-core-system.md",
  "framework/49-engineering-guardian/00-engineering-guardian.md",
  "framework/49-engineering-guardian/01-zero-regression-policy.md",
  "framework/49-engineering-guardian/19-self-criticism-engine.md",
  "framework/49-engineering-guardian/20-final-guardian-gate.md",
  "framework/49-engineering-guardian/25-final-checklist.md",
  "framework/50-environment-bootstrap/00-environment-bootstrap.md",
  "framework/50-environment-bootstrap/01-profile-selection.md",
  "framework/50-environment-bootstrap/02-core-profile.md",
  "framework/50-environment-bootstrap/08-ai-profile.md",
  "framework/50-environment-bootstrap/10-dependency-levels.md",
  "framework/50-environment-bootstrap/11-detection-and-installation.md",
  "framework/50-environment-bootstrap/13-runtime-bootstrap-sequence.md",
  "framework/58-agent-model-orchestration/00-agent-model-orchestration-system.md",
  "framework/58-agent-model-orchestration/01-task-complexity-classifier.md"
)
Add-Unique $gates @(
  "framework/27-quality-gates/16-ueef-activation-gate.md",
  "framework/27-quality-gates/21-engineering-guardian-gate.md",
  "framework/27-quality-gates/22-environment-bootstrap-gate.md",
  "framework/27-quality-gates/31-agent-model-routing-gate.md"
)

$motionRequired = $text -match "motion|animation|animate|transition|easing|micro-interaction|interaction polish"
if ($text -match "ui|ux|frontend|react|angular|design|layout|accessibility|screen|component|css|scss|tailwind" -or $motionRequired) {
  $uiRequired = $true
  Add-Unique $modules @(
    "framework/08-performance/00-performance-philosophy.md",
    "framework/10-frontend/00-frontend-engineering.md",
    "framework/14-ui/00-ui-system.md",
    "framework/15-ux/00-ux-system.md",
    "framework/16-accessibility/00-accessibility-system.md"
  )
  Add-Unique $gates @(
    "framework/27-quality-gates/ui-gate.md",
    "framework/27-quality-gates/ux-gate.md",
    "framework/27-quality-gates/accessibility-gate.md",
    "framework/27-quality-gates/performance-gate.md"
  )
}

if ($text -match "browser|chrome|tab|page inspection|visual verification|screenshot|localhost") {
  Add-Unique $modules @("framework/51-browser-session-control/00-browser-session-first.md")
  Add-Unique $gates @("framework/27-quality-gates/23-browser-session-control-gate.md")
}

if ($text -match "page|layout|visual|design|frontend|screen|responsive|form|dashboard|landing|screenshot") {
  Add-Unique $gates @("framework/27-quality-gates/30-visual-composition-gate.md")
}

if ($text -match "api|endpoint|backend|server|controller|route|service") {
  Add-Unique $modules @(
    "framework/05-architecture/00-clean-architecture.md",
    "framework/07-security/00-security-by-default.md",
    "framework/08-performance/00-performance-philosophy.md",
    "framework/11-backend/00-backend-engineering.md",
    "framework/13-api/00-api-engineering.md"
  )
  Add-Unique $gates @(
    "framework/27-quality-gates/security-gate.md",
    "framework/27-quality-gates/performance-gate.md",
    "framework/27-quality-gates/api-gate.md",
    "framework/27-quality-gates/testing-gate.md"
  )
}

if ($text -match "database|sql|migration|schema|query|index|postgres|sql server|mysql") {
  Add-Unique $modules @(
    "framework/07-security/09-database-security.md",
    "framework/08-performance/00-performance-philosophy.md",
    "framework/12-database/00-database-engineering.md"
  )
  Add-Unique $gates @(
    "framework/27-quality-gates/security-gate.md",
    "framework/27-quality-gates/performance-gate.md",
    "framework/27-quality-gates/database-gate.md"
  )
}

if ($text -match "security|auth|authorization|authentication|secret|owasp|vulnerability|permission") {
  Add-Unique $modules @(
    "framework/07-security/00-security-by-default.md",
    "framework/07-security/01-owasp-review.md",
    "framework/07-security/02-authentication.md",
    "framework/07-security/03-authorization.md",
    "framework/07-security/04-input-validation.md"
  )
  Add-Unique $gates @("framework/27-quality-gates/security-gate.md")
}

if ($text -match "deploy|release|production|ci|cd|pipeline|docker|cloud|rollback") {
  Add-Unique $modules @(
    "framework/19-devops/00-devops-system.md",
    "framework/20-enterprise/00-enterprise-system.md",
    "framework/09-scalability/00-scalability-by-default.md"
  )
  Add-Unique $gates @(
    "framework/27-quality-gates/production-gate.md",
    "framework/27-quality-gates/enterprise-gate.md",
    "framework/27-quality-gates/security-gate.md"
  )
}

if ($text -match "doc|readme|manual|guide|documentation|changelog") {
  Add-Unique $modules @("framework/18-documentation/00-documentation-system.md")
  Add-Unique $gates @("framework/27-quality-gates/documentation-gate.md")
}

if ($text -match "skill|superpower|superpowers|protocol|workflow|red flag|red-flag|tdd|test-driven|subagent review|skill authoring|skill-routing|skill invocation") {
  Add-Unique $modules @(
    "framework/59-skill-invocation-protocol/00-skill-invocation-protocol-system.md"
  )
  Add-Unique $gates @("framework/27-quality-gates/32-skill-invocation-protocol-gate.md")
}

if ($text -match "spec kit|speckit|spec-driven|specification-driven|specification|requirements|acceptance criteria|clarification|ambiguity|technical plan|task breakdown|convergence|constitution|project principles|preset|extension|bundle|third-party attribution") {
  Add-Unique $modules @(
    "framework/60-spec-driven-development/00-spec-driven-development-system.md"
  )
  Add-Unique $gates @("framework/27-quality-gates/33-spec-driven-development-gate.md")
}

if ($text -match "refactor|refactoring|legacy|dead code|obsolete code|modernize|modernise|modernization|modernisation|dependency upgrade|package upgrade|runtime upgrade|framework upgrade|outdated|end of life|eol|technical debt") {
  Add-Unique $modules @(
    "framework/61-project-modernization/00-project-modernization-system.md",
    "framework/61-project-modernization/01-discovery-and-baseline.md",
    "framework/61-project-modernization/02-behavior-preserving-refactoring.md",
    "framework/61-project-modernization/03-dead-and-obsolete-code.md",
    "framework/61-project-modernization/05-technology-currency-assessment.md",
    "framework/61-project-modernization/06-upgrade-decision-and-execution.md",
    "framework/61-project-modernization/08-verification-rollout-and-rollback.md"
  )
  Add-Unique $gates @(
    "framework/27-quality-gates/architecture-gate.md",
    "framework/27-quality-gates/code-quality-gate.md",
    "framework/27-quality-gates/performance-gate.md",
    "framework/27-quality-gates/testing-gate.md",
    "framework/27-quality-gates/34-project-modernization-and-runtime-gate.md"
  )
}

if ($text -match "real.?time|live refresh|auto.?refresh|without reload|no reload|lazy load|lazy loading|code split|code splitting|prefetch|preload") {
  Add-Unique $modules @(
    "framework/47-theme-responsive-interaction-security-performance/42-frontend-rendering-performance.md",
    "framework/47-theme-responsive-interaction-security-performance/43-backend-api-performance.md",
    "framework/47-theme-responsive-interaction-security-performance/50-application-lazy-loading.md",
    "framework/47-theme-responsive-interaction-security-performance/51-global-live-refresh.md"
  )
  Add-Unique $gates @(
    "framework/27-quality-gates/performance-gate.md",
    "framework/27-quality-gates/security-gate.md",
    "framework/27-quality-gates/34-project-modernization-and-runtime-gate.md"
  )
}

Assert-ExistingFrameworkPaths ($modules.ToArray() + $gates.ToArray())

Write-Output "UEEF Quality Gate Selection"
Write-Output "---------------------------"
Write-Output "Task: $Task"
Write-Output "UIUX: $(if ($uiRequired) { 'YES' } else { 'NO' })"
Write-Output "Specialist skill route: $(if ($motionRequired) { 'emil-design-eng' } else { 'none' })"
Write-Output "Selected:"
foreach ($m in $modules) { Write-Output "- $m" }
Write-Output "Gates:"
foreach ($g in $gates) { Write-Output "- $g" }
Write-Output "Gates include framework/27-quality-gates/16-ueef-activation-gate.md"
