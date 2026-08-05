param(
  [Parameter(Mandatory=$true)][string]$Task,
  [ValidateSet('T0','T1','T2','T3','T4')][string]$Tier,
  [switch]$CodeChange,
  [ValidateSet('ui','browser','current-docs','ambiguous','debugging')][string[]]$TaskTag = @(),
  [ValidateSet('Auto','Quick','Build','Audit')][string]$FrontendMode = 'Auto',
  [object]$FrontendRoute,
  [switch]$Json
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'task-language-signals.ps1')
$text = ConvertTo-UeefTaskSignalText $Task
$modules = New-Object System.Collections.Generic.List[string]
$gates = New-Object System.Collections.Generic.List[string]
$skillRoutes = New-Object System.Collections.Generic.List[string]
$uiRequired = $false
$resolvedFrontendMode = 'NA'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$inputParameters = @{} + $PSBoundParameters
if ($FrontendRoute -and ([string]$FrontendRoute.task -ne $Task -or [int]$FrontendRoute.schemaVersion -lt 1)) { throw 'Supplied frontend route does not belong to this task or has an invalid schema.' }
if ($FrontendRoute -and $FrontendMode -ne 'Auto' -and [string]$FrontendRoute.frontendMode -ne $FrontendMode) { throw 'Supplied frontend route does not match the explicit frontend mode.' }

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

$classificationArgs = @{ Task=$Task; Json=$true }
foreach ($name in @('CodeChange','TaskTag')) {
  if ($inputParameters.ContainsKey($name)) { $classificationArgs[$name] = $inputParameters[$name] }
}
if (!$inputParameters.ContainsKey('Tier') -or !$inputParameters.ContainsKey('CodeChange')) {
  $classification = (& (Join-Path $PSScriptRoot 'get-ueef-task-classification.ps1') @classificationArgs | Out-String) | ConvertFrom-Json
}
if (!$Tier) { $Tier = [string]$classification.route.tier }
if (!$inputParameters.ContainsKey('CodeChange')) { $CodeChange = [bool]$classification.values.codeChange }
$effectiveTags = if ($classification) { @($classification.values.taskTags) } else { @($TaskTag) }
if (!$FrontendRoute -and $FrontendMode -eq 'Auto' -and $classification.frontendRoute) { $FrontendRoute = $classification.frontendRoute }

# Every task receives only the non-negotiable core and routing contract.
Add-Unique $modules @(
  "framework/01-core/00-boot-loader.md",
  "framework/01-core/00-core-system.md",
  "framework/19-agent-workflow/01-model-orchestration/00-agent-model-orchestration-system.md",
  "framework/19-agent-workflow/01-model-orchestration/01-task-complexity-classifier.md"
)
Add-Unique $gates @(
  "framework/12-delivery-quality/04-quality-gates/16-ueef-activation-gate.md",
  "framework/12-delivery-quality/04-quality-gates/31-agent-model-routing-gate.md"
)

# T2+ work must carry the guardian and environment contracts. T3/T4 also
# receive the deeper assurance and bootstrap evidence modules.
if ($Tier -in @('T2','T3','T4')) {
  Add-Unique $modules @(
    "framework/12-delivery-quality/08-engineering-guardian/00-engineering-guardian.md",
    "framework/18-runtime-operations/01-environment-bootstrap/00-environment-bootstrap.md"
  )
  Add-Unique $gates @(
    "framework/12-delivery-quality/04-quality-gates/21-engineering-guardian-gate.md",
    "framework/12-delivery-quality/04-quality-gates/22-environment-bootstrap-gate.md"
  )
}
if ($Tier -in @('T3','T4')) {
  Add-Unique $modules @(
    "framework/12-delivery-quality/08-engineering-guardian/01-zero-regression-policy.md",
    "framework/12-delivery-quality/08-engineering-guardian/19-self-criticism-engine.md",
    "framework/12-delivery-quality/08-engineering-guardian/20-final-guardian-gate.md",
    "framework/12-delivery-quality/08-engineering-guardian/25-final-checklist.md",
    "framework/18-runtime-operations/01-environment-bootstrap/01-profile-selection.md",
    "framework/18-runtime-operations/01-environment-bootstrap/02-core-profile.md",
    "framework/18-runtime-operations/01-environment-bootstrap/08-ai-profile.md",
    "framework/18-runtime-operations/01-environment-bootstrap/10-dependency-levels.md",
    "framework/18-runtime-operations/01-environment-bootstrap/11-detection-and-installation.md",
    "framework/18-runtime-operations/01-environment-bootstrap/13-runtime-bootstrap-sequence.md"
  )
}

if ($Tier -eq 'T1' -and $CodeChange) {
  Add-Unique $gates @(
    "framework/12-delivery-quality/04-quality-gates/code-quality-gate.md",
    "framework/12-delivery-quality/04-quality-gates/testing-gate.md"
  )
}

if ($FrontendRoute) {
  $frontendRoute = $FrontendRoute
} else {
  $frontendRouteJson = & node (Join-Path $PSScriptRoot 'select-frontend-route.mjs') --task $Task --mode $FrontendMode
  if ($LASTEXITCODE -ne 0) { throw 'Frontend route engine failed.' }
  $frontendRoute = ($frontendRouteJson | Out-String) | ConvertFrom-Json
}
$motionRequired = @($frontendRoute.domains) | Where-Object { $_ -in @('motion', 'animation') } | Select-Object -First 1
$motionRequired = [bool]$motionRequired
if ($frontendRoute.applies -or $effectiveTags -contains 'ui') {
  $uiRequired = $true
  $resolvedFrontendMode = if ($frontendRoute.applies) { [string]$frontendRoute.frontendMode } elseif ($FrontendMode -ne 'Auto') { $FrontendMode } else { 'Quick' }
  if ($frontendRoute.applies) {
    Add-Unique $modules @($frontendRoute.modules)
    Add-Unique $gates @($frontendRoute.gates)
    Add-Unique $skillRoutes @($frontendRoute.skills)
  } else {
    Add-Unique $modules @('framework/10-frontend/01-engineering/00-frontend-engineering.md','framework/10-frontend/01-engineering/01-frontend-task-modes.md')
    Add-Unique $gates @('framework/12-delivery-quality/04-quality-gates/ui-gate.md')
    Add-Unique $skillRoutes @('typeui-fundamentals')
  }
  if ($effectiveTags -contains 'ambiguous') { Add-Unique $skillRoutes @('design-brief') }
}

if ($effectiveTags -contains 'browser' -or $text -match '\b(browser|chrome|tab|screenshot|localhost)\b|page inspection|visual verification') {
  Add-Unique $modules @("framework/18-runtime-operations/02-browser-session-control/00-browser-session-first.md")
  Add-Unique $gates @("framework/12-delivery-quality/04-quality-gates/23-browser-session-control-gate.md")
}

$visualRequired = $uiRequired -and ($frontendRoute.gates -contains 'framework/12-delivery-quality/04-quality-gates/30-visual-composition-gate.md' -or (
  ($resolvedFrontendMode -eq 'Build' -and $text -match '\b(page|layout|visual|design|screen|responsive|form|dashboard|landing)\b') -or
  ($resolvedFrontendMode -eq 'Audit' -and $text -match '\b(visual|design|layout|screen|responsive|page|form|dashboard|landing|redesign|polish)\b|pixel.?perfect') -or
  ($resolvedFrontendMode -eq 'Quick' -and $text -match 'exact visual|visual verification|visually|screenshot|pixel.?perfect')
))
if ($visualRequired) {
  Add-Unique $gates @("framework/12-delivery-quality/04-quality-gates/30-visual-composition-gate.md")
}

$skeletonRequired = $text -match '\bskeleton\b|loading placeholder|loading state|async state|shimmer|content loader|reveal timing|hydration placeholder'
if ($skeletonRequired) {
  Add-Unique $modules @(
    "framework/17-product-platform/02-skeleton-loading/00-skeleton-loading-system.md",
    "framework/17-product-platform/02-skeleton-loading/01-structure-and-content-parity.md",
    "framework/17-product-platform/02-skeleton-loading/02-state-contract.md"
  )
  Add-Unique $gates @("framework/12-delivery-quality/04-quality-gates/25-skeleton-loading-gate.md")
}

if ($text -match '\b(api|endpoint|backend|server|controller|route|service)\b') {
  Add-Unique $modules @(
    "framework/05-architecture/00-clean-architecture.md",
    "framework/07-security/00-security-by-default.md",
    "framework/08-performance/00-performance-philosophy.md",
    "framework/11-server-side/02-backend/00-backend-engineering.md",
    "framework/11-server-side/01-api/00-api-engineering.md"
  )
  Add-Unique $gates @(
    "framework/12-delivery-quality/04-quality-gates/security-gate.md",
    "framework/12-delivery-quality/04-quality-gates/performance-gate.md",
    "framework/12-delivery-quality/04-quality-gates/api-gate.md",
    "framework/12-delivery-quality/04-quality-gates/testing-gate.md"
  )
}

if ($text -match '\b(database|sql|migration|schema|query|postgres|mysql)\b|sql server|database index|sql index|query index') {
  Add-Unique $modules @(
    "framework/07-security/09-database-security.md",
    "framework/08-performance/00-performance-philosophy.md",
    "framework/11-server-side/03-database/00-database-engineering.md"
  )
  Add-Unique $gates @(
    "framework/12-delivery-quality/04-quality-gates/security-gate.md",
    "framework/12-delivery-quality/04-quality-gates/performance-gate.md",
    "framework/12-delivery-quality/04-quality-gates/database-gate.md"
  )
}

if ($text -match '\b(security|auth|authorization|authentication|secret|owasp|vulnerability|permission)\b') {
  Add-Unique $modules @(
    "framework/07-security/00-security-by-default.md",
    "framework/07-security/01-owasp-review.md",
    "framework/07-security/02-authentication.md",
    "framework/07-security/03-authorization.md",
    "framework/07-security/04-input-validation.md"
  )
  Add-Unique $gates @("framework/12-delivery-quality/04-quality-gates/security-gate.md")
}

if ($text -match '\b(deploy|release|production|ci|cd|pipeline|docker|cloud|rollback)\b') {
  Add-Unique $modules @(
    "framework/12-delivery-quality/03-devops/00-devops-system.md",
    "framework/17-product-platform/05-enterprise/00-enterprise-system.md",
    "framework/09-scalability/00-scalability-by-default.md"
  )
  Add-Unique $gates @(
    "framework/12-delivery-quality/04-quality-gates/production-gate.md",
    "framework/12-delivery-quality/04-quality-gates/enterprise-gate.md",
    "framework/12-delivery-quality/04-quality-gates/security-gate.md"
  )
}

if ($text -match '\b(doc|readme|manual|guide|documentation|changelog)\b') {
  Add-Unique $modules @("framework/12-delivery-quality/02-documentation/00-documentation-system.md")
  Add-Unique $gates @("framework/12-delivery-quality/04-quality-gates/documentation-gate.md")
}

if ($text -match "skill|superpower|superpowers|protocol|workflow|red flag|red-flag|tdd|test-driven|subagent review|skill authoring|skill-routing|skill invocation") {
  Add-Unique $modules @(
    "framework/19-agent-workflow/02-skill-invocation-protocol/00-skill-invocation-protocol-system.md"
  )
  Add-Unique $gates @("framework/12-delivery-quality/04-quality-gates/32-skill-invocation-protocol-gate.md")
}

if ($text -match "spec kit|speckit|spec-driven|specification-driven|specification|requirements|acceptance criteria|clarification|ambiguity|technical plan|task breakdown|convergence|constitution|project principles|preset|extension bundle|spec bundle|workflow bundle|third-party attribution") {
  Add-Unique $modules @(
    "framework/19-agent-workflow/03-spec-driven-development/00-spec-driven-development-system.md"
  )
  Add-Unique $gates @("framework/12-delivery-quality/04-quality-gates/33-spec-driven-development-gate.md")
}

if ($text -match "project-wide refactor|repository-wide refactor|system-wide refactor|legacy|dead code|obsolete code|modernize|modernise|modernization|modernisation|dependency upgrade|package upgrade|runtime upgrade|framework upgrade|outdated|end of life|eol|technical debt") {
  Add-Unique $modules @(
    "framework/20-repository-evolution/01-project-modernization/00-project-modernization-system.md",
    "framework/20-repository-evolution/01-project-modernization/01-discovery-and-baseline.md",
    "framework/20-repository-evolution/01-project-modernization/02-behavior-preserving-refactoring.md",
    "framework/20-repository-evolution/01-project-modernization/03-dead-and-obsolete-code.md",
    "framework/20-repository-evolution/01-project-modernization/05-technology-currency-assessment.md",
    "framework/20-repository-evolution/01-project-modernization/06-upgrade-decision-and-execution.md",
    "framework/20-repository-evolution/01-project-modernization/08-verification-rollout-and-rollback.md"
  )
  Add-Unique $gates @(
    "framework/12-delivery-quality/04-quality-gates/architecture-gate.md",
    "framework/12-delivery-quality/04-quality-gates/code-quality-gate.md",
    "framework/12-delivery-quality/04-quality-gates/performance-gate.md",
    "framework/12-delivery-quality/04-quality-gates/testing-gate.md",
    "framework/12-delivery-quality/04-quality-gates/34-project-modernization-and-runtime-gate.md"
  )
}

if ($text -match "real.?time|live refresh|auto.?refresh|without reload|no reload|lazy load|lazy loading|code split|code splitting|prefetch|preload") {
  Add-Unique $modules @(
    "framework/16-design-system/02-theme-responsive-interaction-security-performance/42-frontend-rendering-performance.md",
    "framework/16-design-system/02-theme-responsive-interaction-security-performance/43-backend-api-performance.md",
    "framework/16-design-system/02-theme-responsive-interaction-security-performance/50-application-lazy-loading.md",
    "framework/16-design-system/02-theme-responsive-interaction-security-performance/51-global-live-refresh.md"
  )
  Add-Unique $gates @(
    "framework/12-delivery-quality/04-quality-gates/performance-gate.md",
    "framework/12-delivery-quality/04-quality-gates/security-gate.md",
    "framework/12-delivery-quality/04-quality-gates/34-project-modernization-and-runtime-gate.md"
  )
}

Assert-ExistingFrameworkPaths ($modules.ToArray() + $gates.ToArray())

$result = [ordered]@{
  schemaVersion = 4
  task = $Task
  tier = $Tier
  codeChange = [bool]$CodeChange
  uiux = if ($uiRequired) { 'YES' } else { 'NO' }
  frontendMode = $resolvedFrontendMode
  frontendRoute = $frontendRoute
  skillRoutes = @($skillRoutes)
  specialistSkillRoute = if ($motionRequired) { 'emil-design-eng' } else { 'none' }
  modules = @($modules)
  gates = @($gates)
}
if ($Json) {
  $result | ConvertTo-Json -Depth 5
  exit 0
}

Write-Output "UEEF Quality Gate Selection"
Write-Output "---------------------------"
Write-Output "Task: $Task"
Write-Output "Tier: $Tier"
Write-Output "UIUX: $(if ($uiRequired) { 'YES' } else { 'NO' })"
Write-Output "Frontend mode: $resolvedFrontendMode"
Write-Output "Skill routes: $(if ($skillRoutes.Count) { $skillRoutes -join ', ' } else { 'none' })"
Write-Output "Specialist skill route: $(if ($motionRequired) { 'emil-design-eng' } else { 'none' })"
Write-Output "Selected:"
foreach ($m in $modules) { Write-Output "- $m" }
Write-Output "Gates:"
foreach ($g in $gates) { Write-Output "- $g" }
Write-Output "Gates include framework/12-delivery-quality/04-quality-gates/16-ueef-activation-gate.md"
