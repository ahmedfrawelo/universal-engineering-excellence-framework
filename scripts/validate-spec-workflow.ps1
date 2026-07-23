[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Path,
  [ValidateSet('Draft','Ready')][string]$Mode = 'Ready',
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$workflowPath = (Resolve-Path -LiteralPath $Path).Path
$required = [ordered]@{
  'constitution.md' = @('# Constitution:', '## Principles', '## Non-negotiable constraints')
  'spec.md' = @('# Specification:', '## Outcome', '## Functional requirements', '## Acceptance criteria')
  'plan.md' = @('# Technical Plan:', '## Requirement mapping', '## Rollout and rollback')
  'tasks.md' = @('# Tasks:', '## Ordered work', '- [ ] TASK-001', 'Requirements: REQ-001', 'Evidence:', 'Done when:')
  'evidence.md' = @('# Evidence:', '## Delivery record', '| Acceptance criterion | Evidence command or review | Result | Recorded at |', '| AC-001 |')
  'clarifications.md' = @('# Clarifications:', '## Clarification register', '| ID | Question | Status | Decision or assumption | Owner | Evidence |', 'CLAR-001')
  'convergence.md' = @('# Convergence:', '## Traceability convergence', '| Requirement or AC | Spec | Plan | Task | Implementation | Evidence | State | Residual risk |', 'REQ-001')
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
if ($tasks -and (($tasks -notmatch 'Evidence:') -or ($tasks -notmatch 'Done when:') -or ($tasks -notmatch 'Requirements: REQ-'))) { $issues.Add('tasks.md must link each task to requirements, evidence, and a completion condition') }
$evidence = Get-Content -LiteralPath (Join-Path $workflowPath 'evidence.md') -Raw -ErrorAction SilentlyContinue
if ($Mode -eq 'Ready' -and $evidence -and $evidence -notmatch '\| AC-[0-9]+ \|.+\|\s*(PASS|FAIL|PENDING)\s*\|.+\|') { $issues.Add('evidence.md must record an AC result as PASS, FAIL, or PENDING') }
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
if ($Json) { $result | ConvertTo-Json -Depth 4 } elseif ($result.valid) { Write-Host "Spec workflow: PASS ($Mode, $workflowPath)" } else { $issues | ForEach-Object { Write-Host "FAIL: $_" }; Write-Host 'Spec workflow: FAIL' }
if (!$result.valid) { exit 1 }
exit 0
