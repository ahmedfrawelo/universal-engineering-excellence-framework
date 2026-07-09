param(
  [Parameter(Mandatory=$true)][string]$Task
)
$ErrorActionPreference = "Stop"
$text = $Task.ToLowerInvariant()
$modules = New-Object System.Collections.Generic.List[string]
$gates = New-Object System.Collections.Generic.List[string]
$uiRequired = $false

function Add-Unique($list, [string[]]$items) {
  foreach ($item in $items) {
    if (!$list.Contains($item)) { [void]$list.Add($item) }
  }
}

Add-Unique $modules @(
  "framework/01-core/00-core-system.md",
  "framework/01-core/01-master-loader.md",
  "framework/01-core/02-master-index.md",
  "framework/01-core/12-ueef-required-preflight.md"
)
Add-Unique $gates @("framework/27-quality-gates/16-ueef-activation-gate.md")

if ($text -match "ui|ux|frontend|react|angular|design|layout|accessibility|screen|component|css|scss|tailwind") {
  $uiRequired = $true
  Add-Unique $modules @(
    "framework/08-performance/01-frontend-performance.md",
    "framework/10-frontend/00-frontend-architecture.md",
    "framework/14-ui/00-ui-excellence.md",
    "framework/15-ux/00-ux-excellence.md",
    "framework/16-accessibility/00-accessibility-excellence.md"
  )
  Add-Unique $gates @(
    "framework/27-quality-gates/08-ui-gate.md",
    "framework/27-quality-gates/09-ux-gate.md",
    "framework/27-quality-gates/10-accessibility-gate.md",
    "framework/27-quality-gates/05-performance-gate.md"
  )
}

if ($text -match "api|endpoint|backend|server|controller|route|service") {
  Add-Unique $modules @(
    "framework/05-architecture/00-clean-architecture.md",
    "framework/07-security/00-security-by-default.md",
    "framework/08-performance/03-backend-performance.md",
    "framework/11-backend/00-backend-architecture.md",
    "framework/13-api/00-api-design.md"
  )
  Add-Unique $gates @(
    "framework/27-quality-gates/04-security-gate.md",
    "framework/27-quality-gates/05-performance-gate.md",
    "framework/27-quality-gates/07-api-gate.md",
    "framework/27-quality-gates/11-testing-gate.md"
  )
}

if ($text -match "database|sql|migration|schema|query|index|postgres|sql server|mysql") {
  Add-Unique $modules @(
    "framework/07-security/07-database-security.md",
    "framework/08-performance/04-database-performance.md",
    "framework/12-database/00-database-architecture.md"
  )
  Add-Unique $gates @(
    "framework/27-quality-gates/04-security-gate.md",
    "framework/27-quality-gates/05-performance-gate.md",
    "framework/27-quality-gates/06-database-gate.md"
  )
}

if ($text -match "security|auth|authorization|authentication|secret|owasp|vulnerability|permission") {
  Add-Unique $modules @(
    "framework/07-security/00-security-by-default.md",
    "framework/07-security/01-owasp-security.md",
    "framework/07-security/03-authentication.md",
    "framework/07-security/04-authorization.md",
    "framework/07-security/05-input-validation.md"
  )
  Add-Unique $gates @("framework/27-quality-gates/04-security-gate.md")
}

if ($text -match "deploy|release|production|ci|cd|pipeline|docker|cloud|rollback") {
  Add-Unique $modules @(
    "framework/19-devops/00-devops-ci-cd.md",
    "framework/20-enterprise/00-enterprise-governance.md",
    "framework/09-scalability/00-scalability-principles.md"
  )
  Add-Unique $gates @(
    "framework/27-quality-gates/13-production-gate.md",
    "framework/27-quality-gates/14-enterprise-gate.md",
    "framework/27-quality-gates/04-security-gate.md"
  )
}

if ($text -match "doc|readme|manual|guide|documentation|changelog") {
  Add-Unique $modules @("framework/18-documentation/00-documentation-engineering.md")
  Add-Unique $gates @("framework/27-quality-gates/12-documentation-gate.md")
}

Write-Output "UEEF Quality Gate Selection"
Write-Output "---------------------------"
Write-Output "Task: $Task"
Write-Output "UI UX Pro Max Required: $(if ($uiRequired) { 'YES' } else { 'NO' })"
Write-Output "Relevant Modules Selected:"
foreach ($m in $modules) { Write-Output "- $m" }
Write-Output "Quality Gates Planned:"
foreach ($g in $gates) { Write-Output "- $g" }
Write-Output "Activation Gate: framework/27-quality-gates/16-ueef-activation-gate.md"
