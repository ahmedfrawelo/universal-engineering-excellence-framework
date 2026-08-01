[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Path,
  [switch]$Json
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Completion audit not found: $Path" }
$audit = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
if ($audit.schemaVersion -ne 1) { throw 'Unsupported completion audit schema.' }
function Assert-Text($Value, [string]$Name) {
  $text=[string]$Value
  if ([string]::IsNullOrWhiteSpace($text) -or $text -match '^(replace-me|todo|tbd)$') { throw "Completion audit requires substantive $Name." }
}
Assert-Text $audit.taskId 'taskId'
Assert-Text $audit.requestedOutcome 'requestedOutcome'
$auditTime=[datetimeoffset]::MinValue
if (![datetimeoffset]::TryParse([string]$audit.auditedAt,[ref]$auditTime)) { throw 'Completion audit requires a valid auditedAt timestamp.' }
$requirements=@($audit.requirements)
$criteria=@($audit.acceptanceCriteria)
if (!$requirements.Count) { throw 'Completion audit requires at least one explicit requirement.' }
if (!$criteria.Count) { throw 'Completion audit requires at least one acceptance criterion.' }
$criterionMap=@{}
foreach($criterion in $criteria){
  Assert-Text $criterion.id 'acceptance criterion id'
  Assert-Text $criterion.text "acceptance criterion '$($criterion.id)' text"
  if($criterionMap.ContainsKey([string]$criterion.id)){throw "Duplicate acceptance criterion id: $($criterion.id)"}
  if([string]$criterion.status -ne 'PASS'){throw "Acceptance criterion '$($criterion.id)' is not PASS."}
  $items=@($criterion.evidence)
  if(!$items.Count){throw "Acceptance criterion '$($criterion.id)' has no evidence."}
  foreach($item in $items){
    Assert-Text $item.kind "evidence kind for '$($criterion.id)'"
    Assert-Text $item.source "evidence source for '$($criterion.id)'"
    if([string]$item.result -ne 'PASS'){throw "Acceptance criterion '$($criterion.id)' contains non-passing evidence."}
    $observed=[datetimeoffset]::MinValue
    if(![datetimeoffset]::TryParse([string]$item.observedAt,[ref]$observed)){throw "Acceptance criterion '$($criterion.id)' evidence lacks a valid observedAt timestamp."}
    if($observed -gt $auditTime.AddMinutes(1)){throw "Acceptance criterion '$($criterion.id)' evidence is newer than the audit."}
  }
  $criterionMap[[string]$criterion.id]=$criterion
}
$linked=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$requirementIds=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach($requirement in $requirements){
  Assert-Text $requirement.id 'requirement id'
  Assert-Text $requirement.text "requirement '$($requirement.id)' text"
  if(!$requirementIds.Add([string]$requirement.id)){throw "Duplicate requirement id: $($requirement.id)"}
  if([string]$requirement.status -ne 'PASS'){throw "Requirement '$($requirement.id)' is not PASS."}
  $links=@($requirement.acceptanceCriteria)
  if(!$links.Count){throw "Requirement '$($requirement.id)' has no acceptance criteria."}
  foreach($id in $links){if(!$criterionMap.ContainsKey([string]$id)){throw "Requirement '$($requirement.id)' references missing criterion '$id'."};[void]$linked.Add([string]$id)}
}
foreach($id in $criterionMap.Keys){if(!$linked.Contains($id)){throw "Acceptance criterion '$id' is not linked to a requirement."}}
if(@($audit.remainingWork).Count){throw 'Completion audit still has remaining work.'}
if(@($audit.knownProblems).Count){throw 'Completion audit still has known problems.'}
if([string]$audit.conclusion -ne 'COMPLETE'){throw 'Completion audit conclusion is not COMPLETE.'}
$result=[pscustomobject]@{schemaVersion=1;status='PASS';taskId=[string]$audit.taskId;requirements=$requirements.Count;acceptanceCriteria=$criteria.Count;path=(Resolve-Path -LiteralPath $Path).Path}
if($Json){$result|ConvertTo-Json -Depth 3}else{$result|Format-List}
