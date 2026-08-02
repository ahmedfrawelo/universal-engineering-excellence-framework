[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Path,
  [switch]$Json
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Completion audit not found: $Path" }
$audit = Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json
if ($audit.schemaVersion -ne 2) { throw 'Completion audit schemaVersion 2 is required for literal goal coverage.' }
function Assert-Text($Value, [string]$Name) {
  $text=[string]$Value
  if ([string]::IsNullOrWhiteSpace($text) -or $text -match '^(replace-me|todo|tbd)$') { throw "Completion audit requires substantive $Name." }
}
Assert-Text $audit.taskId 'taskId'
Assert-Text $audit.requestedOutcome 'requestedOutcome'
$sourceReview = $audit.sourceReview
if ($null -eq $sourceReview) { throw 'Completion audit requires sourceReview for literal goal coverage.' }
if ([string]$sourceReview.coverageMode -ne 'verbatim-segments') { throw 'sourceReview.coverageMode must be verbatim-segments.' }
if ([string]$sourceReview.status -ne 'PASS') { throw 'sourceReview.status must be PASS.' }
Assert-Text $sourceReview.sourceText 'sourceReview.sourceText'
Assert-Text $sourceReview.sourceSha256 'sourceReview.sourceSha256'
$sourceHash = [Security.Cryptography.SHA256]::Create()
try { $actualSourceHash = ([BitConverter]::ToString($sourceHash.ComputeHash([Text.Encoding]::UTF8.GetBytes([string]$sourceReview.sourceText))).Replace('-', '')).ToUpperInvariant() } finally { $sourceHash.Dispose() }
if ($actualSourceHash -ne ([string]$sourceReview.sourceSha256).ToUpperInvariant()) { throw 'sourceReview.sourceSha256 does not match sourceText.' }
$reviewUnits = @($sourceReview.reviewUnits)
if (!$reviewUnits.Count) { throw 'sourceReview requires at least one review unit.' }
$previousEnd = 0
$unitIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($unit in ($reviewUnits | Sort-Object { [int]$_.start })) {
  Assert-Text $unit.id 'sourceReview review unit id'
  if (!$unitIds.Add([string]$unit.id)) { throw "Duplicate sourceReview review unit id: $($unit.id)" }
  if ([string]$unit.status -ne 'PASS') { throw "Source review unit '$($unit.id)' is not PASS." }
  if ([string]$unit.classification -notin @('requirement','constraint','instruction','context','non-goal')) { throw "Source review unit '$($unit.id)' has an invalid classification." }
  $start = [int]$unit.start; $end = [int]$unit.end
  if ($start -lt 0 -or $end -le $start -or $end -gt ([string]$sourceReview.sourceText).Length) { throw "Source review unit '$($unit.id)' has invalid bounds." }
  if ($start -lt $previousEnd) { throw "Source review units overlap at '$($unit.id)'." }
  $gap = ([string]$sourceReview.sourceText).Substring($previousEnd, $start - $previousEnd)
  if ($gap -match '\S') { throw "Unreviewed non-whitespace source text exists before '$($unit.id)'." }
  $expectedQuote = ([string]$sourceReview.sourceText).Substring($start, $end - $start)
  if ([string]$unit.sourceQuote -cne $expectedQuote) { throw "Source review unit '$($unit.id)' sourceQuote does not match its bounds." }
  if (@($unit.linkedRequirements).Count -eq 0) { throw "Source review unit '$($unit.id)' must link to at least one requirement." }
  $previousEnd = $end
}
$tail = ([string]$sourceReview.sourceText).Substring($previousEnd)
if ($tail -match '\S') { throw 'Unreviewed non-whitespace source text remains after the final source review unit.' }
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
foreach($unit in $reviewUnits){ foreach($requirementId in @($unit.linkedRequirements)){ if(!$requirementIds.Contains([string]$requirementId)){ throw "Source review unit '$($unit.id)' references missing requirement '$requirementId'." } } }
foreach($id in $criterionMap.Keys){if(!$linked.Contains($id)){throw "Acceptance criterion '$id' is not linked to a requirement."}}
$implementationReview=$audit.implementationReview
if($null -eq $implementationReview){throw 'Completion audit requires implementationReview.'}
$implementationCompletedAt=[datetimeoffset]::MinValue
$goalReviewStartedAt=[datetimeoffset]::MinValue
if(![datetimeoffset]::TryParse([string]$implementationReview.implementationCompletedAt,[ref]$implementationCompletedAt)){throw 'implementationReview requires a valid implementationCompletedAt.'}
if(![datetimeoffset]::TryParse([string]$implementationReview.goalReviewStartedAt,[ref]$goalReviewStartedAt)){throw 'implementationReview requires a valid goalReviewStartedAt.'}
if($goalReviewStartedAt -lt $implementationCompletedAt){throw 'Goal review cannot start before implementation is complete.'}
if(!$implementationReview.transitionAnnounced -or !$implementationReview.goalRemainedActiveDuringReview){throw 'Implementation completion must be announced before goal review while the goal remains ACTIVE.'}
if([string]$implementationReview.requestedImplementationStatus -ne 'PASS' -or [string]$implementationReview.bestFeasibleOutcomeStatus -ne 'PASS' -or [string]$implementationReview.goalToImplementationComparisonStatus -ne 'PASS' -or [string]$implementationReview.status -ne 'PASS'){throw 'implementationReview must PASS requested implementation, actual implementation comparison, and best feasible outcome.'}
Assert-Text $implementationReview.bestFeasibleOutcomeRationale 'implementationReview.bestFeasibleOutcomeRationale'
$actualInventory=@($implementationReview.actualImplementationInventory)
if(!$actualInventory.Count){throw 'implementationReview requires an actual implementation inventory.'}
if(@($implementationReview.missingImplementation).Count){throw 'Required implementation is still missing; implement it and repeat the comparison.'}
if(@($implementationReview.untracedImplementation).Count){throw 'Untraced implementation remains outside the requirement comparison.'}
$implementationMap=@{}
foreach($actual in $actualInventory){
  Assert-Text $actual.id 'actual implementation id';Assert-Text $actual.surface 'actual implementation surface';Assert-Text $actual.observedBehavior 'actual implementation observed behavior';Assert-Text $actual.evidence 'actual implementation evidence'
  if($implementationMap.ContainsKey([string]$actual.id)){throw "Duplicate actual implementation id: $($actual.id)"}
  if([string]$actual.status -ne 'PASS' -or !@($actual.linkedRequirements).Count){throw "Actual implementation '$($actual.id)' is not traced PASS."}
  foreach($id in @($actual.linkedRequirements)){if(!$requirementIds.Contains([string]$id)){throw "Actual implementation '$($actual.id)' references missing requirement '$id'."}}
  $implementationMap[[string]$actual.id]=$actual
}
$unitMap=@{};foreach($unit in $reviewUnits){$unitMap[[string]$unit.id]=$unit}
$checklist=@($audit.completionChecklist)
if($checklist.Count -ne $requirements.Count){throw 'completionChecklist must contain exactly one item per requirement.'}
$checkedRequirementIds=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach($item in $checklist){
  $requirementId=[string]$item.requirementId
  if(!$requirementIds.Contains($requirementId) -or !$checkedRequirementIds.Add($requirementId)){throw "completionChecklist contains a missing or duplicate requirement: $requirementId"}
  if(!$item.checked -or [string]$item.status -ne 'PASS' -or [string]$item.requestedImplementationStatus -ne 'PASS' -or [string]$item.bestFeasibleOutcomeStatus -ne 'PASS' -or [string]$item.goalToImplementationComparisonStatus -ne 'PASS'){throw "completionChecklist item '$requirementId' is not fully compared and checked PASS."}
  Assert-Text $item.bestFeasibleOutcomeRationale "completionChecklist item '$requirementId' best feasible outcome rationale"
  $requiredCriterionIds=@(($requirements|Where-Object{[string]$_.id -eq $requirementId}).acceptanceCriteria)
  $itemCriterionIds=@($item.acceptanceCriteria)
  foreach($id in $requiredCriterionIds){if($itemCriterionIds -notcontains $id){throw "completionChecklist item '$requirementId' omits acceptance criterion '$id'."}}
  $itemUnitIds=@($item.sourceReviewUnits)
  if(!$itemUnitIds.Count){throw "completionChecklist item '$requirementId' has no source review units."}
  foreach($id in $itemUnitIds){if(!$unitMap.ContainsKey([string]$id) -or @($unitMap[[string]$id].linkedRequirements) -notcontains $requirementId){throw "completionChecklist item '$requirementId' has invalid source review unit '$id'."}}
  $actualIds=@($item.actualImplementationIds)
  if(!$actualIds.Count){throw "completionChecklist item '$requirementId' has no actual implementation evidence."}
  foreach($id in $actualIds){if(!$implementationMap.ContainsKey([string]$id) -or @($implementationMap[[string]$id].linkedRequirements) -notcontains $requirementId){throw "completionChecklist item '$requirementId' has invalid actual implementation '$id'."}}
}
$regressionReview=$audit.regressionReview
if($null -eq $regressionReview -or [string]$regressionReview.status -ne 'PASS'){throw 'Completion audit requires a passing regressionReview.'}
Assert-Text $regressionReview.scope 'regressionReview.scope'
if(!@($regressionReview.changedSurfaces).Count -or !@($regressionReview.checks).Count){throw 'regressionReview requires changed surfaces and focused checks.'}
foreach($check in @($regressionReview.checks)){Assert-Text $check.surface 'regression check surface';Assert-Text $check.evidence 'regression check evidence';if([string]$check.result -ne 'PASS'){throw "Regression check '$($check.surface)' is not PASS."}}
if(@($regressionReview.taskCausedRegressions).Count){throw 'Task-caused regressions remain; fix them before completion.'}
foreach($finding in @($regressionReview.unrelatedFindings)){Assert-Text $finding.description 'unrelated finding description';Assert-Text $finding.evidence 'unrelated finding evidence';Assert-Text $finding.outOfScopeReason 'unrelated finding out-of-scope reason'}
$userCommitmentReview=$audit.userCommitmentReview
if($null -eq $userCommitmentReview -or [string]$userCommitmentReview.status -ne 'PASS'){throw 'Completion audit requires a passing userCommitmentReview.'}
if(@($userCommitmentReview.pendingCommitments).Count){throw 'An explicit before-finish user commitment remains pending.'}
if($userCommitmentReview.explicitBeforeFinishRequestDetected -and !$userCommitmentReview.clarificationAskedBeforeCompletion){throw 'The user declared a before-finish commitment, but the required clarification was not asked before completion.'}
if(!@($userCommitmentReview.resolutionEvidence).Count){throw 'userCommitmentReview requires resolution evidence.'}
foreach($item in @($userCommitmentReview.resolutionEvidence)){Assert-Text $item 'user commitment resolution evidence'}
$goalUpdateReview=$audit.goalUpdateReview
if($null -eq $goalUpdateReview -or [string]$goalUpdateReview.status -ne 'PASS'){throw 'Completion audit requires a passing goalUpdateReview.'}
if(!$goalUpdateReview.allReceivedUpdatesClassified -or [string]$goalUpdateReview.updateDetectionStatus -ne 'PASS'){throw 'Every received goal update must be detected and classified.'}
$updatesReceived=[int]$goalUpdateReview.updatesReceived
$updateRoutes=@($goalUpdateReview.routes)
if($updatesReceived -lt 0 -or $updateRoutes.Count -ne $updatesReceived){throw 'goalUpdateReview routes must account for every received update.'}
if(@($goalUpdateReview.pendingUpdates).Count -or @($goalUpdateReview.openResumePoints).Count){throw 'Goal updates or resume points remain pending.'}
$updateIds=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach($route in $updateRoutes){
  Assert-Text $route.id 'goal update route id';Assert-Text $route.summary 'goal update route summary';Assert-Text $route.targetStep 'goal update target step';Assert-Text $route.resolutionEvidence 'goal update resolution evidence'
  if(!$updateIds.Add([string]$route.id)){throw "Duplicate goal update route id: $($route.id)"}
  if([string]$route.relation -notin @('CURRENT_STEP','PRIOR_STEP_CORRECTION','FUTURE_STEP','INVALIDATES_CURRENT_WORK','CONFLICT_OR_AMBIGUOUS')){throw "Invalid goal update relation: $($route.relation)"}
  if([string]$route.status -ne 'PASS'){throw "Goal update route '$($route.id)' is not PASS."}
}
if(@($audit.remainingWork).Count){throw 'Completion audit still has remaining work.'}
if(@($audit.knownProblems).Count){throw 'Completion audit still has known problems.'}
if([string]$audit.conclusion -ne 'COMPLETE'){throw 'Completion audit conclusion is not COMPLETE.'}
$result=[pscustomobject]@{schemaVersion=2;status='PASS';taskId=[string]$audit.taskId;requirements=$requirements.Count;acceptanceCriteria=$criteria.Count;reviewUnits=$reviewUnits.Count;checklistItems=$checklist.Count;taskCausedRegressions=@($regressionReview.taskCausedRegressions).Count;unrelatedFindings=@($regressionReview.unrelatedFindings).Count;path=(Resolve-Path -LiteralPath $Path).Path}
if($Json){$result|ConvertTo-Json -Depth 3}else{$result|Format-List}
