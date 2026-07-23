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
$casualBrowserMention = & $selector -Task 'Document the browser policy in this repository' -Json | ConvertFrom-Json
if ($casualBrowserMention.mcps -contains 'node_repl') { throw 'A casual browser mention must not select browser control.' }
Assert-Profile 'Fix a reproducible validation regression' 'SELECTIVE' @() @() @('systematic-debugging','tdd-evidence-loop') @{ 'systematic-debugging'='required'; 'tdd-evidence-loop'='required_when_practical' }
Assert-Profile 'Clarify ambiguous requirements for a new feature' 'SELECTIVE' @() @() @('brainstorming-and-clarification') @{ 'brainstorming-and-clarification'='recommended' }
Assert-Profile 'Perform a production payment migration' 'ASSURED' @() @() @('independent-review','evidence-loop') @{ 'independent-review'='required'; 'evidence-loop'='required' }
$explicit = & $selector -Task 'Plain implementation request' -TaskTag browser -RouteTier T3 -RiskFloor Security -CodeChange -Json | ConvertFrom-Json
if ($explicit.profile -ne 'ASSURED' -or $explicit.mcps -notcontains 'node_repl' -or $explicit.classificationEvidence.source -ne 'explicit' -or $explicit.classificationEvidence.routeTier -ne 'T3' -or $explicit.classificationEvidence.riskFloor -ne 'Security') { throw 'Explicit route signals must override keyword inference and remain explainable.' }
Write-Host 'Capability profile tests passed'
