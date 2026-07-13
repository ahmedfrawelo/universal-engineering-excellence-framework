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
  param([string]$Task)
  $lines = @(& $selector -Task $Task)
  $selectedIndex = [Array]::IndexOf([string[]]$lines, 'Selected:')
  $gatesIndex = [Array]::IndexOf([string[]]$lines, 'Gates:')

  if ($selectedIndex -lt 0 -or $gatesIndex -lt 0 -or $gatesIndex -le $selectedIndex) {
    throw "Selector returned an invalid format for '$Task'."
  }

  $modules = @($lines[($selectedIndex + 1)..($gatesIndex - 1)] | Where-Object { $_ -like '- *' } | ForEach-Object { $_.Substring(2) })
  $gates = @($lines[($gatesIndex + 1)..($lines.Length - 1)] | Where-Object { $_ -like '- *' } | ForEach-Object { $_.Substring(2) })
  $uiux = (($lines | Where-Object { $_ -like 'UIUX:*' }) -replace '^UIUX:\s*', '')

  [PSCustomObject]@{
    Modules = $modules
    Gates = $gates
    UIUX = $uiux
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
    Name = 'chrome-visual'
    Task = 'Inspect the frontend page visually in the existing Chrome tab on localhost'
    UIUX = 'YES'
    Modules = @('framework/51-browser-session-control/00-browser-session-first.md')
    Gates = @('framework/27-quality-gates/23-browser-session-control-gate.md', 'framework/27-quality-gates/30-visual-composition-gate.md')
  }
)

foreach ($case in $cases) {
  $selection = Get-QualityGateSelection -Task $case.Task
  if ($selection.UIUX -ne $case.UIUX) {
    throw "$($case.Name) expected UIUX '$($case.UIUX)', got '$($selection.UIUX)'."
  }

  Assert-Contains -Actual $selection.Modules -Expected @('framework/01-core/00-boot-loader.md', 'framework/01-core/00-core-system.md') -Context $case.Name
  Assert-Contains -Actual $selection.Modules -Expected @('framework/49-engineering-guardian/00-engineering-guardian.md', 'framework/50-environment-bootstrap/00-environment-bootstrap.md', 'framework/58-agent-model-orchestration/00-agent-model-orchestration-system.md') -Context $case.Name
  Assert-Contains -Actual $selection.Gates -Expected @('framework/27-quality-gates/16-ueef-activation-gate.md', 'framework/27-quality-gates/21-engineering-guardian-gate.md', 'framework/27-quality-gates/22-environment-bootstrap-gate.md', 'framework/27-quality-gates/31-agent-model-routing-gate.md') -Context $case.Name
  Assert-Contains -Actual $selection.Modules -Expected $case.Modules -Context $case.Name
  Assert-Contains -Actual $selection.Gates -Expected $case.Gates -Context $case.Name
  Assert-ExistingPaths -Paths ($selection.Modules + $selection.Gates) -Context $case.Name
}

Write-Host 'Quality gate selection tests passed'
