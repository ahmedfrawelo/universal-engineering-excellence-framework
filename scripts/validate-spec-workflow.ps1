[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Path,
  [ValidateSet('Draft','Ready')][string]$Mode = 'Ready',
  [switch]$Quiet,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$workflowPath = (Resolve-Path -LiteralPath $Path).Path
$required = [ordered]@{
  'constitution.md' = @('# Constitution:', '## Principles', '## Non-negotiable constraints')
  'spec.md' = @('# Specification:', '## Outcome', '## Functional requirements', '## Acceptance criteria')
  'plan.md' = @('# Technical Plan:', '## Token and worker budget', 'Token budget mode:', 'Delegation policy:', 'Maximum worker count:', 'Worker output cap:', '## Requirement mapping', '## Rollout and rollback')
  'tasks.md' = @('# Tasks:', '## Ordered work', 'TASK-001', 'Requirements: REQ-001', 'Delegation:', 'Allowed write set:', 'Forbidden paths:', 'Evidence:', 'Done when:')
  'evidence.md' = @('# Evidence:', '## Delivery record', '| Acceptance criterion | Evidence command or review | Result | Recorded at |', '| AC-001 |', '## Token economy record', 'Actual worker count:', 'Worker results integrated or discarded:')
  'clarifications.md' = @('# Clarifications:', '## Clarification register', '| ID | Question | Status | Decision or assumption | Owner | Evidence |', 'CLAR-001')
  'convergence.md' = @('# Convergence:', '## Traceability convergence', '| Requirement or AC | Spec | Plan | Task | Implementation | Evidence | State | Residual risk |', 'REQ-001', '## Token and worker budget convergence', 'Worker outputs within cap:', 'Token-saving shortcuts removed required evidence:')
  'task-graph.json' = @()
}
$issues = [Collections.Generic.List[string]]::new()
$spec = Get-Content -LiteralPath (Join-Path $workflowPath 'spec.md') -Raw -ErrorAction SilentlyContinue
if ($Mode -eq 'Ready' -and $spec -and $spec -notmatch '(?m)^\s*(?:-\s+)?(REQ|FR|NFR)-[A-Za-z0-9._-]+:') { $issues.Add('spec.md must declare at least one structured requirement ID (REQ-, FR-, or NFR-).') }
if ($Mode -eq 'Ready' -and $spec -and $spec -notmatch '(?m)^\s*(?:-\s+)?(AC|ACC)-[A-Za-z0-9._-]+:') { $issues.Add('spec.md must declare at least one structured acceptance ID (AC- or ACC-).') }
foreach ($item in $required.GetEnumerator()) {
  $file = Join-Path $workflowPath $item.Key
  if (!(Test-Path -LiteralPath $file -PathType Leaf)) { $issues.Add("Missing required artifact: $($item.Key)"); continue }
  $content = Get-Content -LiteralPath $file -Raw
  foreach ($term in $item.Value) { if ($content -notmatch [regex]::Escape($term)) { $issues.Add("$($item.Key) is missing required section: $term") } }
  if ($Mode -eq 'Ready' -and $content -match '\{\{[A-Z0-9_]+\}\}') { $issues.Add("$($item.Key) contains unresolved placeholders") }
}
$tasks = Get-Content -LiteralPath (Join-Path $workflowPath 'tasks.md') -Raw -ErrorAction SilentlyContinue
if ($tasks -and (($tasks -notmatch 'Evidence:') -or ($tasks -notmatch 'Done when:') -or ($tasks -notmatch 'Requirements: REQ-') -or ($tasks -notmatch 'Delegation:') -or ($tasks -notmatch 'Allowed write set:') -or ($tasks -notmatch 'Forbidden paths:'))) { $issues.Add('tasks.md must link each task to requirements, delegation scope, write boundaries, evidence, and a completion condition') }
$graphPath = Join-Path $workflowPath 'task-graph.json'
if (Test-Path -LiteralPath $graphPath -PathType Leaf) {
  $engine = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\invoke-spec-workflow-engine.ps1'
  $graphOutput = & $engine validate --graph $graphPath 2>&1
  if ($LASTEXITCODE -ne 0) {
    $issues.Add('task-graph.json failed engine validation: ' + (($graphOutput | Out-String).Trim()))
  } else {
    try {
      $graph = Get-Content -LiteralPath $graphPath -Raw | ConvertFrom-Json
      if ($graph.workflowId -ne (Split-Path -Leaf $workflowPath)) {
        $issues.Add('task-graph.json workflowId must match the specification folder name')
      }
      if ($Mode -eq 'Ready' -and $tasks) {
        $markdownTaskIds = @([regex]::Matches($tasks, '(?m)^- \[[ xX]\] (TASK-[A-Za-z0-9._-]+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        $graphTaskIds = @($graph.tasks | ForEach-Object { $_.id } | Sort-Object -Unique)
        if (($markdownTaskIds -join ',') -ne ($graphTaskIds -join ',')) {
          $issues.Add('tasks.md and task-graph.json must declare the same task IDs')
        }
      }
    } catch {
      $issues.Add('task-graph.json could not be parsed for artifact consistency: ' + $_.Exception.Message)
    }
  }
}
$plan = Get-Content -LiteralPath (Join-Path $workflowPath 'plan.md') -Raw -ErrorAction SilentlyContinue
if ($Mode -eq 'Ready' -and $plan) {
  if ($plan -notmatch '(?m)^-\s*Token budget mode:\s*(minimal|bounded|expanded)\s*$') { $issues.Add('plan.md must record token budget mode as minimal, bounded, or expanded') }
  if ($plan -notmatch '(?m)^-\s*Delegation policy:\s*(none|sidecar|parallel-specialists|lead-workers-verifier)\s*$') { $issues.Add('plan.md must record a valid delegation policy') }
  if ($plan -notmatch '(?m)^-\s*Maximum worker count:\s*\d+\s*$') { $issues.Add('plan.md must record a numeric maximum worker count') }
  if ($graph -and $plan -match '(?m)^-\s*Maximum worker count:\s*(\d+)\s*$' -and [int]$Matches[1] -ne [int]$graph.policy.maxWorkers) { $issues.Add('plan.md maximum worker count must match task-graph.json policy.maxWorkers') }
}
$evidence = Get-Content -LiteralPath (Join-Path $workflowPath 'evidence.md') -Raw -ErrorAction SilentlyContinue
if ($Mode -eq 'Ready' -and $evidence -and $evidence -notmatch '\| AC-[0-9]+ \|.+\|\s*(PASS|FAIL|PENDING)\s*\|.+\|') { $issues.Add('evidence.md must record an AC result as PASS, FAIL, or PENDING') }
if ($Mode -eq 'Ready' -and $evidence -and $evidence -notmatch '(?m)^-\s*Actual worker count:\s*\d+\s*$') { $issues.Add('evidence.md must record a numeric actual worker count') }
$clarifications = Get-Content -LiteralPath (Join-Path $workflowPath 'clarifications.md') -Raw -ErrorAction SilentlyContinue
if ($Mode -eq 'Ready' -and $clarifications -and $clarifications -match '(?m)^\|\s*CLAR-[0-9]+\s*\|.*\|\s*OPEN\s*\|') { $issues.Add('clarifications.md cannot contain OPEN items in Ready mode') }
$convergence = Get-Content -LiteralPath (Join-Path $workflowPath 'convergence.md') -Raw -ErrorAction SilentlyContinue
if ($Mode -eq 'Ready' -and $convergence) {
  $requirements = [regex]::Matches((Get-Content -LiteralPath (Join-Path $workflowPath 'spec.md') -Raw), '(?m)^\s*(?:-\s+)?((?:REQ|FR|NFR)-[A-Za-z0-9._-]+):') | ForEach-Object { $_.Groups[1].Value }
  $acceptance = [regex]::Matches((Get-Content -LiteralPath (Join-Path $workflowPath 'spec.md') -Raw), '(?m)^\s*(?:-\s+)?((?:AC|ACC)-[A-Za-z0-9._-]+):') | ForEach-Object { $_.Groups[1].Value }
  foreach ($id in @(@($requirements) + @($acceptance) | Sort-Object -Unique)) {
    if ($convergence -notmatch "(?m)^\|\s*$([regex]::Escape($id))\s*\|") { $issues.Add("convergence.md must trace $id") }
  }
}
$result = [ordered]@{ schemaVersion=1; workflowPath=$workflowPath; mode=$Mode; valid=($issues.Count -eq 0); issues=@($issues) }
if ($Json) { $result | ConvertTo-Json -Depth 4 } elseif (!$Quiet -and $result.valid) { Write-Host "Spec workflow: PASS ($Mode, $workflowPath)" } elseif (!$Quiet) { $issues | ForEach-Object { Write-Host "FAIL: $_" }; Write-Host 'Spec workflow: FAIL' }
if (!$result.valid) { exit 1 }
exit 0
