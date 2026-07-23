$ErrorActionPreference = 'Stop'
$selector = Join-Path $PSScriptRoot 'select-capability-profile.ps1'
function Assert-Profile([string]$Task, [string]$ExpectedProfile, [string[]]$Skills = @(), [string[]]$Mcps = @()) {
  $actual = & $selector -Task $Task -Json | ConvertFrom-Json
  if ($actual.profile -ne $ExpectedProfile) { throw "Expected $ExpectedProfile for '$Task', got $($actual.profile)." }
  foreach ($skill in $Skills) { if ($actual.skills -notcontains $skill) { throw "Missing skill $skill for '$Task'." } }
  foreach ($mcp in $Mcps) { if ($actual.mcps -notcontains $mcp) { throw "Missing MCP $mcp for '$Task'." } }
}
Assert-Profile 'Explain dependency injection' 'CORE_ONLY'
Assert-Profile 'Build a React accessible dashboard' 'SELECTIVE' @('ui-ux-pro-max','impeccable')
Assert-Profile 'Check the latest OpenAI API documentation' 'SELECTIVE' @('.system/openai-docs')
Assert-Profile 'Inspect the existing Chrome tab visually' 'SELECTIVE' @() @('node_repl')
Assert-Profile 'Perform a production payment migration' 'ASSURED'
Write-Host 'Capability profile tests passed'
