$ErrorActionPreference = 'Stop'
$selector = Join-Path $PSScriptRoot 'select-capability-profile.ps1'
function Assert-Profile([string]$Task, [string]$ExpectedProfile, [string[]]$Skills = @(), [string[]]$Mcps = @(), [string[]]$Workflows = @(), [hashtable]$Selections = @{}) {
  $actual = & $selector -Task $Task -Json | ConvertFrom-Json
  if ($actual.profile -ne $ExpectedProfile) { throw "Expected $ExpectedProfile for '$Task', got $($actual.profile)." }
  foreach ($skill in $Skills) { if ($actual.skills -notcontains $skill) { throw "Missing skill $skill for '$Task'." } }
  foreach ($mcp in $Mcps) { if ($actual.mcps -notcontains $mcp) { throw "Missing MCP $mcp for '$Task'." } }
  foreach ($workflow in $Workflows) { if ($actual.workflows -notcontains $workflow) { throw "Missing workflow $workflow for '$Task'." } }
  foreach ($workflow in $Selections.Keys) { $decision = $actual.workflowDecisions | Where-Object { $_.id -eq $workflow }; if (!$decision -or $decision.selection -ne $Selections[$workflow] -or !$decision.evidence) { throw "Workflow decision contract failed for $workflow in '$Task'." } }
}
Assert-Profile 'Explain dependency injection' 'CORE_ONLY'
Assert-Profile 'Build a React accessible dashboard' 'SELECTIVE' @('ui-ux-pro-max','impeccable')
Assert-Profile 'Check the latest OpenAI API documentation' 'SELECTIVE' @('.system/openai-docs')
Assert-Profile 'Inspect the existing Chrome tab visually' 'SELECTIVE' @() @('node_repl')
Assert-Profile 'Fix a reproducible validation regression' 'SELECTIVE' @() @() @('systematic-debugging','tdd-evidence-loop') @{ 'systematic-debugging'='required'; 'tdd-evidence-loop'='required_when_practical' }
Assert-Profile 'Clarify ambiguous requirements for a new feature' 'SELECTIVE' @() @() @('brainstorming-and-clarification') @{ 'brainstorming-and-clarification'='recommended' }
Assert-Profile 'Perform a production payment migration' 'ASSURED' @() @() @('independent-review','evidence-loop') @{ 'independent-review'='required'; 'evidence-loop'='required' }
Write-Host 'Capability profile tests passed'
