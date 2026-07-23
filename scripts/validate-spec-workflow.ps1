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
  'spec.md' = @('# Specification:', '## Outcome', '## Functional requirements', '## Acceptance criteria', 'REQ-001:', 'AC-001:')
  'plan.md' = @('# Technical Plan:', '## Requirement mapping', '## Rollout and rollback')
  'tasks.md' = @('# Tasks:', '## Ordered work', '- [ ] TASK-001', 'Requirements: REQ-001', 'Evidence:', 'Done when:')
  'evidence.md' = @('# Evidence:', '## Delivery record', '| Acceptance criterion | Evidence command or review | Result | Recorded at |', '| AC-001 |')
}
$issues = [Collections.Generic.List[string]]::new()
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
$result = [ordered]@{ schemaVersion=1; workflowPath=$workflowPath; mode=$Mode; valid=($issues.Count -eq 0); issues=@($issues) }
if ($Json) { $result | ConvertTo-Json -Depth 4 } elseif ($result.valid) { Write-Host "Spec workflow: PASS ($Mode, $workflowPath)" } else { $issues | ForEach-Object { Write-Host "FAIL: $_" }; Write-Host 'Spec workflow: FAIL' }
if (!$result.valid) { exit 1 }
exit 0
