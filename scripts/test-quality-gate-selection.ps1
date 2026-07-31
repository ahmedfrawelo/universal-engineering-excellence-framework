$ErrorActionPreference = 'Stop'
$selector = Join-Path $PSScriptRoot 'select-quality-gates.ps1'
$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Assert-Contains {
  param([string[]]$Actual, [string[]]$Expected, [string]$Context)
  foreach ($item in $Expected) {
    if ($Actual -notcontains $item) {
      throw "$Context did not select '$item'."
    }
  }
}

function Get-QualityGateSelection {
  param(
    [string]$Task,
    [ValidateSet('Auto','Quick','Build','Audit')][string]$FrontendMode = 'Auto'
  )
  $lines = @(& $selector -Task $Task -FrontendMode $FrontendMode)
  $selectedIndex = [Array]::IndexOf([string[]]$lines, 'Selected:')
  $gatesIndex = [Array]::IndexOf([string[]]$lines, 'Gates:')

  if ($selectedIndex -lt 0 -or $gatesIndex -lt 0 -or $gatesIndex -le $selectedIndex) {
    throw "Selector returned an invalid format for '$Task'."
  }

  $modules = @($lines[($selectedIndex + 1)..($gatesIndex - 1)] | Where-Object { $_ -like '- *' } | ForEach-Object { $_.Substring(2) })
  $gates = @($lines[($gatesIndex + 1)..($lines.Length - 1)] | Where-Object { $_ -like '- *' } | ForEach-Object { $_.Substring(2) })
  $uiux = (($lines | Where-Object { $_ -like 'UIUX:*' }) -replace '^UIUX:\s*', '')
  $tier = (($lines | Where-Object { $_ -like 'Tier:*' }) -replace '^Tier:\s*', '')
  $resolvedFrontendMode = (($lines | Where-Object { $_ -like 'Frontend mode:*' }) -replace '^Frontend mode:\s*', '')
  $skillLine = (($lines | Where-Object { $_ -like 'Skill routes:*' }) -replace '^Skill routes:\s*', '')
  $skills = if ($skillLine -and $skillLine -ne 'none') { @($skillLine -split ',\s*') } else { @() }

  [PSCustomObject]@{
    Modules = $modules
    Gates = $gates
    UIUX = $uiux
    Tier = $tier
    FrontendMode = $resolvedFrontendMode
    Skills = $skills
  }
}

function Assert-ExistingPaths {
  param([string[]]$Paths, [string]$Context)
  foreach ($path in $Paths) {
    if (!(Test-Path -LiteralPath (Join-Path $repositoryRoot $path) -PathType Leaf)) {
      throw "$Context emitted missing path '$path'."
    }
  }
}

$cases = @(
  @{
    Name = 'frontend'
    Task = 'Build a frontend React dashboard'
    UIUX = 'YES'
    Modules = @('framework/08-performance/00-performance-philosophy.md', 'framework/10-frontend/00-frontend-engineering.md')
    Gates = @('framework/27-quality-gates/ui-gate.md', 'framework/27-quality-gates/ux-gate.md', 'framework/27-quality-gates/accessibility-gate.md', 'framework/27-quality-gates/performance-gate.md')
  },
  @{
    Name = 'backend'
    Task = 'Implement a backend API endpoint'
    UIUX = 'NO'
    Modules = @('framework/05-architecture/00-clean-architecture.md', 'framework/11-backend/00-backend-engineering.md', 'framework/13-api/00-api-engineering.md')
    Gates = @('framework/27-quality-gates/security-gate.md', 'framework/27-quality-gates/api-gate.md', 'framework/27-quality-gates/testing-gate.md')
  },
  @{
    Name = 'security'
    Task = 'Harden authentication and authorization security'
    UIUX = 'NO'
    Modules = @('framework/07-security/01-owasp-review.md', 'framework/07-security/02-authentication.md', 'framework/07-security/03-authorization.md', 'framework/07-security/04-input-validation.md')
    Gates = @('framework/27-quality-gates/security-gate.md')
  },
  @{
    Name = 'database'
    Task = 'Create a SQL schema migration'
    UIUX = 'NO'
    Modules = @('framework/07-security/09-database-security.md', 'framework/08-performance/00-performance-philosophy.md', 'framework/12-database/00-database-engineering.md')
    Gates = @('framework/27-quality-gates/database-gate.md')
  },
  @{
    Name = 'devops'
    Task = 'Deploy a production CI pipeline'
    UIUX = 'NO'
    Modules = @('framework/19-devops/00-devops-system.md', 'framework/20-enterprise/00-enterprise-system.md', 'framework/09-scalability/00-scalability-by-default.md')
    Gates = @('framework/27-quality-gates/production-gate.md', 'framework/27-quality-gates/enterprise-gate.md')
  },
  @{
    Name = 'ui'
    Task = 'Polish a UI component layout'
    UIUX = 'YES'
    Modules = @('framework/14-ui/00-ui-system.md', 'framework/15-ux/00-ux-system.md', 'framework/16-accessibility/00-accessibility-system.md')
    Gates = @('framework/27-quality-gates/ui-gate.md', 'framework/27-quality-gates/ux-gate.md', 'framework/27-quality-gates/accessibility-gate.md')
  },
  @{
    Name = 'motion'
    Task = 'Implement a motion transition with easing and animation polish'
    UIUX = 'YES'
    Modules = @('framework/08-performance/00-performance-philosophy.md', 'framework/10-frontend/00-frontend-engineering.md', 'framework/14-ui/00-ui-system.md')
    Gates = @('framework/27-quality-gates/ui-gate.md', 'framework/27-quality-gates/ux-gate.md', 'framework/27-quality-gates/accessibility-gate.md', 'framework/27-quality-gates/performance-gate.md')
  },
  @{
    Name = 'chrome-visual'
    Task = 'Inspect the frontend page visually in the existing Chrome tab on localhost'
    UIUX = 'YES'
    Modules = @('framework/51-browser-session-control/00-browser-session-first.md')
    Gates = @('framework/27-quality-gates/23-browser-session-control-gate.md', 'framework/27-quality-gates/30-visual-composition-gate.md')
  },
  @{
    Name = 'skill-protocol'
    Task = 'Add a Superpowers inspired skill invocation protocol with TDD red flags and subagent review'
    UIUX = 'NO'
    Modules = @('framework/59-skill-invocation-protocol/00-skill-invocation-protocol-system.md')
    Gates = @('framework/27-quality-gates/32-skill-invocation-protocol-gate.md')
  },
  @{
    Name = 'spec-driven'
    Task = 'Use Spec Kit style specification-driven development with acceptance criteria, technical plan, task breakdown, and convergence'
    UIUX = 'NO'
    Modules = @('framework/60-spec-driven-development/00-spec-driven-development-system.md')
    Gates = @('framework/27-quality-gates/33-spec-driven-development-gate.md')
  },
  @{
    Name = 'modernization'
    Task = 'Refactor a legacy project, remove proven dead code, and plan outdated dependency upgrades'
    UIUX = 'NO'
    Modules = @('framework/61-project-modernization/00-project-modernization-system.md', 'framework/61-project-modernization/02-behavior-preserving-refactoring.md', 'framework/61-project-modernization/05-technology-currency-assessment.md')
    Gates = @('framework/27-quality-gates/architecture-gate.md', 'framework/27-quality-gates/code-quality-gate.md', 'framework/27-quality-gates/34-project-modernization-and-runtime-gate.md')
  },
  @{
    Name = 'live-lazy-performance'
    Task = 'Add realtime live refresh without reload and lazy loading with backend performance'
    UIUX = 'NO'
    Modules = @('framework/47-theme-responsive-interaction-security-performance/50-application-lazy-loading.md', 'framework/47-theme-responsive-interaction-security-performance/51-global-live-refresh.md')
    Gates = @('framework/27-quality-gates/performance-gate.md', 'framework/27-quality-gates/security-gate.md', 'framework/27-quality-gates/34-project-modernization-and-runtime-gate.md')
  }
)

foreach ($case in $cases) {
  $selection = Get-QualityGateSelection -Task $case.Task
  if ($selection.UIUX -ne $case.UIUX) {
    throw "$($case.Name) expected UIUX '$($case.UIUX)', got '$($selection.UIUX)'."
  }

  Assert-Contains -Actual $selection.Modules -Expected @('framework/01-core/00-boot-loader.md', 'framework/01-core/00-core-system.md') -Context $case.Name
  Assert-Contains -Actual $selection.Modules -Expected @('framework/58-agent-model-orchestration/00-agent-model-orchestration-system.md') -Context $case.Name
  Assert-Contains -Actual $selection.Gates -Expected @('framework/27-quality-gates/16-ueef-activation-gate.md', 'framework/27-quality-gates/31-agent-model-routing-gate.md') -Context $case.Name
  if ($selection.Tier -in @('T2','T3','T4')) {
    Assert-Contains -Actual $selection.Modules -Expected @('framework/49-engineering-guardian/00-engineering-guardian.md', 'framework/50-environment-bootstrap/00-environment-bootstrap.md') -Context "$($case.Name) elevated"
    Assert-Contains -Actual $selection.Gates -Expected @('framework/27-quality-gates/21-engineering-guardian-gate.md', 'framework/27-quality-gates/22-environment-bootstrap-gate.md') -Context "$($case.Name) elevated"
  } else {
    foreach ($forbidden in @('framework/49-engineering-guardian/00-engineering-guardian.md','framework/50-environment-bootstrap/00-environment-bootstrap.md')) {
      if ($selection.Modules -contains $forbidden) { throw "$($case.Name) low-tier task selected broad module '$forbidden'." }
    }
    if ($case.Task -match '\b(build|implement|add|change|refactor|fix|create|update|remove|delete|harden|polish|upgrade|write|edit|deploy|release)\b') {
      Assert-Contains -Actual $selection.Gates -Expected @('framework/27-quality-gates/code-quality-gate.md', 'framework/27-quality-gates/testing-gate.md') -Context "$($case.Name) code-change"
    }
  }
  Assert-Contains -Actual $selection.Modules -Expected $case.Modules -Context $case.Name
  Assert-Contains -Actual $selection.Gates -Expected $case.Gates -Context $case.Name
  Assert-ExistingPaths -Paths ($selection.Modules + $selection.Gates) -Context $case.Name
}

$negativeCases = @(
  @{ Task = 'Audit framework documentation'; ForbiddenModules = @('framework/10-frontend/00-frontend-engineering.md','framework/12-database/00-database-engineering.md','framework/51-browser-session-control/00-browser-session-first.md') },
  @{ Task = 'Review documentation index'; ForbiddenModules = @('framework/12-database/00-database-engineering.md') },
  @{ Task = 'Review release index'; ForbiddenModules = @('framework/12-database/00-database-engineering.md') },
  @{ Task = 'Build backend API'; ForbiddenModules = @('framework/10-frontend/00-frontend-engineering.md') }
)
foreach ($case in $negativeCases) {
  $selection = Get-QualityGateSelection -Task $case.Task
  foreach ($forbidden in $case.ForbiddenModules) {
    if ($selection.Modules -contains $forbidden) {
      throw "'$($case.Task)' selected false-positive module '$forbidden'."
    }
  }
  if ($case.Task -eq 'Audit framework documentation' -and $selection.UIUX -ne 'NO') {
    throw 'Audit text triggered UIUX through a substring match.'
  }
}

$coreOnly = Get-QualityGateSelection -Task 'Explain dependency injection'
if ($coreOnly.Tier -ne 'T0') { throw "A self-contained explanation must remain T0, got $($coreOnly.Tier)." }
if ($coreOnly.FrontendMode -ne 'NA') { throw "A non-UI explanation must use frontend mode NA, got $($coreOnly.FrontendMode)." }
foreach ($forbidden in @('framework/49-engineering-guardian/00-engineering-guardian.md','framework/50-environment-bootstrap/00-environment-bootstrap.md','framework/27-quality-gates/code-quality-gate.md','framework/27-quality-gates/testing-gate.md')) {
  if ($coreOnly.Modules -contains $forbidden -or $coreOnly.Gates -contains $forbidden) {
    throw "T0 core-only selection included '$forbidden'."
  }
}

$quick = Get-QualityGateSelection -Task 'Fix spacing in an existing CSS component'
if ($quick.FrontendMode -ne 'Quick') { throw "A bounded CSS fix must select Quick, got $($quick.FrontendMode)." }
Assert-Contains -Actual $quick.Modules -Expected @('framework/10-frontend/01-frontend-task-modes.md') -Context 'frontend quick'
Assert-Contains -Actual $quick.Gates -Expected @('framework/27-quality-gates/ui-gate.md','framework/27-quality-gates/accessibility-gate.md') -Context 'frontend quick'
Assert-Contains -Actual $quick.Skills -Expected @('typeui-fundamentals') -Context 'frontend quick skills'
foreach ($forbidden in @('framework/15-ux/00-ux-system.md','framework/08-performance/00-performance-philosophy.md','framework/54-design-intelligence/00-design-intelligence-system.md')) {
  if ($quick.Modules -contains $forbidden) { throw "Frontend Quick selected broad module '$forbidden'." }
}
foreach ($forbidden in @('framework/27-quality-gates/ux-gate.md','framework/27-quality-gates/performance-gate.md','framework/27-quality-gates/30-visual-composition-gate.md')) {
  if ($quick.Gates -contains $forbidden) { throw "Frontend Quick selected broad gate '$forbidden'." }
}

$build = Get-QualityGateSelection -Task 'Build a new React dashboard'
if ($build.FrontendMode -ne 'Build') { throw "A new dashboard must select Build, got $($build.FrontendMode)." }
Assert-Contains -Actual $build.Modules -Expected @('framework/15-ux/00-ux-system.md','framework/08-performance/00-performance-philosophy.md') -Context 'frontend build'
Assert-Contains -Actual $build.Gates -Expected @('framework/27-quality-gates/ux-gate.md','framework/27-quality-gates/performance-gate.md','framework/27-quality-gates/30-visual-composition-gate.md') -Context 'frontend build'
Assert-Contains -Actual $build.Skills -Expected @('typeui-fundamentals','frontend-design') -Context 'frontend build skills'
if ($build.Skills -contains 'impeccable' -or $build.Skills -contains 'ui-ux-pro-max') { throw 'Frontend Build stacked audit or intelligence skills without their triggers.' }

$audit = Get-QualityGateSelection -Task 'Audit and polish the frontend visual design'
if ($audit.FrontendMode -ne 'Audit') { throw "A frontend audit must select Audit, got $($audit.FrontendMode)." }
Assert-Contains -Actual $audit.Modules -Expected @('framework/54-design-intelligence/00-design-intelligence-system.md') -Context 'frontend audit'
Assert-Contains -Actual $audit.Gates -Expected @('framework/27-quality-gates/30-visual-composition-gate.md') -Context 'frontend audit'
Assert-Contains -Actual $audit.Skills -Expected @('typeui-fundamentals','impeccable') -Context 'frontend audit skills'
if ($audit.Skills -contains 'frontend-design' -or $audit.Skills -contains 'ui-ux-pro-max') { throw 'Frontend Audit stacked build or intelligence skills without their triggers.' }

$explicitQuick = Get-QualityGateSelection -Task 'Build a UI component using the existing owner' -FrontendMode Quick
if ($explicitQuick.FrontendMode -ne 'Quick') { throw 'An explicit frontend mode must override automatic inference.' }

$loading = Get-QualityGateSelection -Task 'Add a skeleton loading state to a React card'
Assert-Contains -Actual $loading.Modules -Expected @('framework/53-skeleton-loading/00-skeleton-loading-system.md','framework/53-skeleton-loading/01-structure-and-content-parity.md','framework/53-skeleton-loading/02-state-contract.md') -Context 'explicit skeleton route'
Assert-Contains -Actual $loading.Gates -Expected @('framework/27-quality-gates/25-skeleton-loading-gate.md') -Context 'explicit skeleton route'

$dataOnly = Get-QualityGateSelection -Task 'Fix spacing in a data-backed React card'
if ($dataOnly.Modules -contains 'framework/53-skeleton-loading/00-skeleton-loading-system.md' -or $dataOnly.Gates -contains 'framework/27-quality-gates/25-skeleton-loading-gate.md') {
  throw 'A data-backed component selected skeleton workflow without a loading-behavior trigger.'
}

Write-Host 'Quality gate selection tests passed'
