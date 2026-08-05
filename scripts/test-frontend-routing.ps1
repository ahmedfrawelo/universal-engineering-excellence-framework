$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
& node (Join-Path $PSScriptRoot 'test-frontend-routing.mjs')
if ($LASTEXITCODE -ne 0) { throw 'Canonical frontend routing tests failed.' }

$quality = (& (Join-Path $PSScriptRoot 'select-quality-gates.ps1') -Task 'Audit CSS bundle size' -Tier T1 -Json | Out-String) | ConvertFrom-Json
if ($quality.modules -contains 'framework/19-agent-workflow/03-spec-driven-development/00-spec-driven-development-system.md') { throw 'CSS bundle size collided with spec bundle routing.' }
$refactor = (& (Join-Path $PSScriptRoot 'select-quality-gates.ps1') -Task 'Refactor React component internals' -Tier T1 -Json | Out-String) | ConvertFrom-Json
if ($refactor.modules -match 'framework/20-repository-evolution/01-project-modernization') { throw 'Focused refactor over-selected modernization.' }
if ($refactor.frontendRoute.reasons.Count -eq 0 -or $refactor.frontendRoute.confidence -lt 0.6) { throw 'Integrated route lost explainability.' }

$samples = 1..20 | ForEach-Object { Measure-Command { & node (Join-Path $PSScriptRoot 'select-frontend-route.mjs') --task 'Fix dropdown focus' | Out-Null } }
$average = ($samples | Measure-Object TotalMilliseconds -Average).Average
if ($average -gt 150) { throw "Frontend route average exceeded 150ms: $average" }
Write-Host ("Frontend routing integration and performance tests passed ({0:N1}ms average process time)" -f $average)
