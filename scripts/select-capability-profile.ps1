[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Task,
  [ValidateSet('low','medium','high','critical')][string]$Risk = 'low',
  [ValidateSet('ui','browser','current-docs','ambiguous','debugging')][string[]]$TaskTag = @(),
  [ValidateSet('T0','T1','T2','T3','T4')][string]$RouteTier,
  [ValidateSet('None','Architecture','Authentication','Authorization','Security','Production','Migration','Destructive','Privacy','Payment','Incident','Release')][string]$RiskFloor = 'None',
  [switch]$CodeChange,
  [ValidateSet('explicit','inferred','mixed')][string]$ClassificationSource,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$inputParameters = @{} + $PSBoundParameters
$text = $Task.ToLowerInvariant()
$skills = [Collections.Generic.List[string]]::new()
$mcps = [Collections.Generic.List[string]]::new()
$workflows = [Collections.Generic.List[string]]::new()
$workflowDecisions = [Collections.Generic.List[object]]::new()
$reasons = [Collections.Generic.List[string]]::new()
$frontendMode = 'NA'
function Add-Unique([Collections.Generic.List[string]]$List, [string]$Value) { if (!$List.Contains($Value)) { $List.Add($Value) } }
function Add-WorkflowDecision([string]$Id, [string]$Selection, [string]$Trigger, [string]$Evidence) {
  Add-Unique $workflows $Id
  if (!($workflowDecisions | Where-Object { $_.id -eq $Id })) { $workflowDecisions.Add([pscustomobject]@{ id=$Id; selection=$Selection; trigger=$Trigger; evidence=$Evidence }) }
}

$explicitTags = $inputParameters.ContainsKey('TaskTag')
$explicitRouteTier = $inputParameters.ContainsKey('RouteTier')
$explicitRiskFloor = $inputParameters.ContainsKey('RiskFloor')
$explicitCodeChange = $inputParameters.ContainsKey('CodeChange')
$explicitRisk = $inputParameters.ContainsKey('Risk')
$hasExplicitClassification = $explicitTags -or $explicitRouteTier -or $explicitRiskFloor -or $explicitCodeChange -or $explicitRisk
$isReadOnly = $text -match '\b(explain|answer|summari[sz]e|translate|define|what is|review status)\b' -and $text -notmatch '\b(current|latest|online|browser|file|repository|code)\b' -and !$CodeChange
$needsBrowser = ($text -match '\b(open|navigate|inspect|click|type|upload|download|authenticate|log.?in|browse|screenshot|visual(?:ly)? verify|visual check)\b') -and ($text -match '\b(browser|chrome|tab|website|web page|site|figma)\b')
$needsCurrentDocs = ($text -match '\b(latest|current|up.to.date|newest|recent)\b') -and ($text -match '\b(documentation|docs|api|sdk|library|package|model|specification|standard|version)\b')
$isUi = ($text -match '\b(ui|ux|frontend|react|angular|css|layout|accessibility|screen|component|dashboard|visual design)\b') -and ($text -match '\b(build|implement|create|change|update|fix|polish|design|style|render|audit|review|inspect|verify)\b')
$isSecurity = $Risk -in @('high','critical') -or $text -match '\b(security|auth|payment|privacy|production|migration|destructive)\b'
$isAmbiguous = $text -match '\b(ambiguous|unclear|brainstorm|explore|idea|requirements|acceptance criteria)\b'
$isDebugging = $text -match '\b(bug|debug|regression|failure|broken|error|fix)\b'
$isCodeChange = $text -match '\b(build|implement|add|change|refactor|fix|repair|migrat\w*|create|update|remove|delete|harden|polish|upgrade|replace|write|edit|integrate|deploy|release)\b'

# Explicit route signals refine their own dimensions; they do not erase
# unrelated semantics inferred from the task text.
if ($TaskTag -contains 'browser') { $needsBrowser = $true }
if ($TaskTag -contains 'current-docs') { $needsCurrentDocs = $true }
if ($TaskTag -contains 'ui') { $isUi = $true }
if ($TaskTag -contains 'ambiguous') { $isAmbiguous = $true }
if ($TaskTag -contains 'debugging') { $isDebugging = $true }
if ($explicitCodeChange) { $isCodeChange = $CodeChange.IsPresent }
$CodeChange = [bool]$isCodeChange
$isSecurity = $isSecurity -or $RouteTier -in @('T3','T4') -or $RiskFloor -ne 'None'

if ($isReadOnly) {
  $profile = 'CORE_ONLY'
  Add-Unique $reasons 'The request is self-contained and read-only.'
} elseif ($isSecurity -or $RouteTier -in @('T3','T4')) {
  $profile = 'ASSURED'
  Add-Unique $reasons 'High-impact or regulated work needs verified capabilities and independent evidence.'
} else {
  $profile = 'SELECTIVE'
  Add-Unique $reasons 'Use only capabilities directly justified by the task.'
}

if ($isUi) {
  $selectorArgs = @{ Task=$Task; CodeChange=[bool]$CodeChange; Json=$true }
  if ($RouteTier) { $selectorArgs.Tier = $RouteTier }
  if ($TaskTag.Count) { $selectorArgs.TaskTag = $TaskTag }
  $uiRoute = (& (Join-Path $PSScriptRoot 'select-quality-gates.ps1') @selectorArgs | Out-String) | ConvertFrom-Json
  $frontendMode = [string]$uiRoute.frontendMode
  foreach ($skill in @($uiRoute.skillRoutes)) { Add-Unique $skills ([string]$skill) }
  Add-Unique $reasons "UI work uses the $frontendMode frontend mode and only independently triggered design skills."
}
if ($needsCurrentDocs) { Add-Unique $skills '.system/openai-docs'; Add-Unique $reasons 'The task requests current documentation.' }
if ($needsBrowser) { Add-Unique $mcps 'node_repl'; Add-Unique $reasons 'Existing browser/session work requires the Node REPL browser control channel.' }
if ($isSecurity) { Add-Unique $reasons 'Run the relevant security and rollback gates; do not assume optional MCP availability.' }
if ($isAmbiguous) { Add-WorkflowDecision 'brainstorming-and-clarification' 'recommended' 'The request contains ambiguity or exploration language.' 'Resolved assumptions or clarification record before implementation.'; Add-Unique $reasons 'Ambiguity warrants a bounded clarification workflow before implementation.' }
if ($isDebugging) { Add-WorkflowDecision 'systematic-debugging' 'required' 'The request names a bug, regression, error, or failure.' 'Reproduction plus focused regression evidence.'; Add-WorkflowDecision 'tdd-evidence-loop' 'required_when_practical' 'A reproducible behavior failure is present.' 'Focused test, or an explicit alternate evidence source.'; Add-Unique $reasons 'A regression or failure requires reproduction and focused evidence before changing code.' }
elseif ($isCodeChange) { Add-WorkflowDecision 'evidence-loop' 'required' 'The request changes behavior or implementation.' 'Focused test, build, static check, or visual/API evidence.'; Add-Unique $reasons 'A code change requires focused verification, even when test-first is not practical.' }
if ($isSecurity) { Add-WorkflowDecision 'independent-review' 'required' 'The task is high-impact or has a high/critical risk trigger.' 'Spec-compliance and quality-review evidence.'; Add-Unique $reasons 'High-impact work requires a spec and quality review chain.' }

$result = [ordered]@{
  schemaVersion = 2
  profile = $profile
  task = $Task
  frontendMode = $frontendMode
  skills = @($skills)
  mcps = @($mcps)
  workflows = @($workflows)
  workflowDecisions = @($workflowDecisions)
  capabilityHealthRequired = ($profile -eq 'ASSURED' -or $mcps.Count -gt 0)
  classificationEvidence = [ordered]@{
    source = if ($ClassificationSource) { $ClassificationSource } elseif ($explicitTags -and $explicitRouteTier -and $explicitRiskFloor -and $explicitCodeChange) { 'explicit' } elseif ($hasExplicitClassification) { 'mixed' } else { 'inferred' }
    taskTags = @($TaskTag)
    routeTier = $RouteTier
    riskFloor = $RiskFloor
    codeChange = $CodeChange.IsPresent
    explicitInputs = @(
      if ($explicitTags) { 'TaskTag' }
      if ($explicitRouteTier) { 'RouteTier' }
      if ($explicitRiskFloor) { 'RiskFloor' }
      if ($explicitCodeChange) { 'CodeChange' }
      if ($explicitRisk) { 'Risk' }
    )
  }
  reasons = @($reasons)
}
if ($Json) { $result | ConvertTo-Json -Depth 3 } else {
  Write-Output "Capability profile: $($result.profile)"
  Write-Output "Skills: $(if($skills.Count){$skills -join ', '}else{'none'})"
  Write-Output "MCPs: $(if($mcps.Count){$mcps -join ', '}else{'none'})"
  Write-Output "Workflows: $(if($workflows.Count){$workflows -join ', '}else{'none'})"
  Write-Output "Capability health required: $($result.capabilityHealthRequired)"
  $reasons | ForEach-Object { Write-Output "Reason: $_" }
}
