$ErrorActionPreference = 'Stop'
$validator = Join-Path $PSScriptRoot 'validate-goal-lifecycle.ps1'
$auditPath=Join-Path ([IO.Path]::GetTempPath()) ('ueef-goal-audit-'+[guid]::NewGuid().ToString('N')+'.json')
$now=[datetimeoffset]::Now.ToString('o')
$sourceText='Fixture goal.'
$hash=([BitConverter]::ToString(([Security.Cryptography.SHA256]::Create()).ComputeHash([Text.Encoding]::UTF8.GetBytes($sourceText))).Replace('-','')).ToUpperInvariant()
[ordered]@{schemaVersion=2;taskId='goal-fixture';auditedAt=$now;requestedOutcome='Fixture outcome';sourceReview=[ordered]@{coverageMode='verbatim-segments';sourceText=$sourceText;sourceSha256=$hash;status='PASS';reviewUnits=@([ordered]@{id='RU-1';classification='requirement';sourceQuote=$sourceText;start=0;end=$sourceText.Length;status='PASS';linkedRequirements=@('REQ-1')})};requirements=@([ordered]@{id='REQ-1';text='Fixture requirement';status='PASS';acceptanceCriteria=@('AC-1')});acceptanceCriteria=@([ordered]@{id='AC-1';text='Fixture behavior verified';status='PASS';evidence=@([ordered]@{kind='test';source='test-goal-lifecycle';result='PASS';observedAt=$now})});implementationReview=[ordered]@{implementationCompletedAt=$now;goalReviewStartedAt=$now;transitionAnnounced=$true;goalRemainedActiveDuringReview=$true;requestedImplementationStatus='PASS';bestFeasibleOutcomeStatus='PASS';bestFeasibleOutcomeRationale='Canonical implementation satisfies the requested behavior.';status='PASS'};completionChecklist=@([ordered]@{requirementId='REQ-1';sourceReviewUnits=@('RU-1');acceptanceCriteria=@('AC-1');requestedImplementationStatus='PASS';bestFeasibleOutcomeStatus='PASS';bestFeasibleOutcomeRationale='Requirement is satisfied with current evidence.';checked=$true;status='PASS'});regressionReview=[ordered]@{scope='Task changes only';changedSurfaces=@('goal lifecycle fixture');checks=@([ordered]@{surface='goal lifecycle fixture';evidence='focused lifecycle test';result='PASS'});taskCausedRegressions=@();unrelatedFindings=@();status='PASS'};remainingWork=@();knownProblems=@();limitations=@();conclusion='COMPLETE'}|ConvertTo-Json -Depth 8|Set-Content $auditPath -Encoding utf8
$auditFixture=Get-Content -LiteralPath $auditPath -Raw -Encoding utf8|ConvertFrom-Json
$auditFixture|Add-Member -NotePropertyName userCommitmentReview -NotePropertyValue ([pscustomobject]@{explicitBeforeFinishRequestDetected=$false;clarificationAskedBeforeCompletion=$false;resolutionEvidence=@('No before-finish commitment in fixture.');pendingCommitments=@();status='PASS'})
$auditFixture|Add-Member -NotePropertyName goalUpdateReview -NotePropertyValue ([pscustomobject]@{updatesReceived=0;routes=@();pendingUpdates=@();openResumePoints=@();status='PASS'})
$auditFixture.implementationReview|Add-Member -NotePropertyName goalToImplementationComparisonStatus -NotePropertyValue 'PASS'
$auditFixture.implementationReview|Add-Member -NotePropertyName actualImplementationInventory -NotePropertyValue @([pscustomobject]@{id='IMP-1';surface='goal lifecycle fixture';observedBehavior='Fixture behavior passes';evidence='focused lifecycle test';linkedRequirements=@('REQ-1');status='PASS'})
$auditFixture.implementationReview|Add-Member -NotePropertyName untracedImplementation -NotePropertyValue @()
$auditFixture.implementationReview|Add-Member -NotePropertyName missingImplementation -NotePropertyValue @()
$auditFixture.completionChecklist[0]|Add-Member -NotePropertyName actualImplementationIds -NotePropertyValue @('IMP-1')
$auditFixture.completionChecklist[0]|Add-Member -NotePropertyName goalToImplementationComparisonStatus -NotePropertyValue 'PASS'
$auditFixture.goalUpdateReview|Add-Member -NotePropertyName allReceivedUpdatesClassified -NotePropertyValue $true
$auditFixture.goalUpdateReview|Add-Member -NotePropertyName updateDetectionStatus -NotePropertyValue 'PASS'
$auditFixture|ConvertTo-Json -Depth 8|Set-Content $auditPath -Encoding utf8
function Assert-Rejected([hashtable]$Arguments) {
  $rejected = $false
  try { & $validator @Arguments | Out-Null } catch { $rejected = $true }
  if (!$rejected) { throw "Lifecycle case was incorrectly accepted: $($Arguments | ConvertTo-Json -Compress)" }
}
Assert-Rejected @{GoalStatus='ACTIVE';TerminalFinal=$true}
Assert-Rejected @{GoalStatus='COMPLETE';TerminalFinal=$true;RequiredWorkRemaining=$true}
Assert-Rejected @{GoalStatus='BLOCKED';TerminalFinal=$true}
Assert-Rejected @{GoalStatus='BLOCKED';TerminalFinal=$true;BlockerExternalOrUserOnly=$true;ExternalStateChangeRequired=$true}
Assert-Rejected @{GoalStatus='COMPLETE';TerminalFinal=$true;RequestedOutcomeSatisfied=$true;GatesPassOrAccepted=$true;VerificationRecorded=$true;BrowserVerificationRequired=$true}
Assert-Rejected @{GoalStatus='COMPLETE';TerminalFinal=$true;RequestedOutcomeSatisfied=$true;GatesPassOrAccepted=$true;VerificationRecorded=$true;VisualVerificationRequired=$true}
Assert-Rejected @{GoalStatus='COMPLETE';TerminalFinal=$true;RequestedOutcomeSatisfied=$true;GatesPassOrAccepted=$true;VerificationRecorded=$true;BrowserVerificationRequired=$true;VisualVerificationRequired=$true}
Assert-Rejected @{GoalStatus='BLOCKED';TerminalFinal=$true;BlockerExternalOrUserOnly=$true;NoMeaningfulLocalWorkRemaining=$true;ExternalStateChangeRequired=$true;ThreadControlChannelDegraded=$true}
Assert-Rejected @{GoalStatus='BLOCKED';TerminalFinal=$true;BlockerExternalOrUserOnly=$true;NoMeaningfulLocalWorkRemaining=$true;ExternalStateChangeRequired=$true;BrowserVerificationRequired=$true}
Assert-Rejected @{GoalStatus='ACTIVE';BrowserVerificationRequired=$true;VerifiedBrowserEvidenceHandoff=$true}
Assert-Rejected @{GoalStatus='ACTIVE';UserRestartChromeRequested=$true}
Assert-Rejected @{GoalStatus='ACTIVE';ThreadControlChannelDegraded=$true;UserFacingStatus='Browser bridge failed three times.'}
Assert-Rejected @{GoalStatus='ACTIVE';ThreadControlChannelDegraded=$true;UserFacingStatus='Stopped visual verification.'}
Assert-Rejected @{GoalStatus='ACTIVE';ThreadControlChannelDegraded=$true;BrowserFailureStage='tab discovery';BrowserFailureReason='channel failed';BrowserFailureNextAction='retry Chrome';UserFacingStatus='Browser verification is being completed on your existing tab; implementation continues.'}
Assert-Rejected @{GoalStatus='ACTIVE';ThreadControlChannelDegraded=$true;BrowserFailureStage='tab discovery';BrowserFailureReason='cookie token leaked';BrowserFailureNextAction='retry Chrome';UserFacingStatus='Chrome recovery: stage=tab discovery; reason=cookie token leaked; next=retry Chrome. Implementation continues.'}
Assert-Rejected @{GoalStatus='BLOCKED';TerminalFinal=$true;BlockerExternalOrUserOnly=$true;NoMeaningfulLocalWorkRemaining=$true;ExternalStateChangeRequired=$true;PendingScreenshotEvidence=$true}
Assert-Rejected @{GoalStatus='ACTIVE';ImplementationComplete=$true}
Assert-Rejected @{GoalStatus='COMPLETE';ImplementationComplete=$true;GoalReviewStarted=$true;GoalReviewChecklistCreated=$true;TaskRegressionReviewStarted=$true}
Assert-Rejected @{GoalStatus='ACTIVE';UserBeforeFinishCommitmentPending=$true;TerminalFinal=$true}
$baseUpdate=@{GoalStatus='ACTIVE';GoalUpdateReceived=$true;GoalUpdateRoute='CURRENT_STEP';GoalUpdateSummary='Add validation to current contract';GoalUpdateImpactReason='The update belongs to the active lifecycle step';GoalUpdateAcceptanceCriteria='Focused update route test passes';GoalUpdatePlanUpdated=$true;CurrentStepPreserved=$true;CurrentStepUpdateIntegrated=$true}
function Copy-GoalUpdateCase { $copy=@{};foreach($key in $baseUpdate.Keys){$copy[$key]=$baseUpdate[$key]};return $copy }
$case=Copy-GoalUpdateCase;$case.GoalUpdateRoute='UNKNOWN';Assert-Rejected $case
$case=Copy-GoalUpdateCase;$case.GoalUpdatePlanUpdated=$false;Assert-Rejected $case
Assert-Rejected @{GoalStatus='ACTIVE';GoalUpdateReceived=$true;GoalUpdateRoute='PRIOR_STEP_CORRECTION';GoalUpdateSummary='Correct prior contract';GoalUpdateImpactReason='Prior output is incomplete';GoalUpdateAcceptanceCriteria='Prior step reverified';GoalUpdatePlanUpdated=$true}
Assert-Rejected @{GoalStatus='ACTIVE';GoalUpdateReceived=$true;GoalUpdateRoute='FUTURE_STEP';GoalUpdateSummary='Queue later behavior';GoalUpdateImpactReason='Dependency is not ready';GoalUpdateAcceptanceCriteria='Future task eventually passes';GoalUpdatePlanUpdated=$true;CurrentStepPreserved=$true;FutureStepQueued=$true}
Assert-Rejected @{GoalStatus='ACTIVE';GoalUpdateReceived=$true;GoalUpdateRoute='INVALIDATES_CURRENT_WORK';GoalUpdateSummary='Replace invalid plan';GoalUpdateImpactReason='Current work would be wrong';GoalUpdateAcceptanceCriteria='Replanned work passes';GoalUpdatePlanUpdated=$true;ResumePointRecorded=$true;CurrentStepPaused=$true}
Assert-Rejected @{GoalStatus='ACTIVE';GoalUpdateReceived=$true;GoalUpdateRoute='CONFLICT_OR_AMBIGUOUS';GoalUpdateSummary='Conflicting requirement';GoalUpdateImpactReason='Two goals conflict';GoalUpdateAcceptanceCriteria='User resolves conflict';GoalUpdatePlanUpdated=$true;ResumePointRecorded=$true;CurrentStepPreserved=$true}
$validProgress=@{GoalStatus='ACTIVE';ProgressUpdate=$true;ProgressPercent=50;ProgressCurrentStepPercent=35;ProgressPhase='implementation';ProgressUnderstanding='Add dual progress reporting';ProgressCurrentStep='Update the lifecycle contract';ProgressEvidence='Current validator inspected';ProgressCurrentAction='Implement validator fields';ProgressNextGate='Run lifecycle tests'}
function Copy-ProgressCase { $copy=@{}; foreach($key in $validProgress.Keys){$copy[$key]=$validProgress[$key]}; return $copy }
$case=Copy-ProgressCase; $case.ProgressPercent=80; Assert-Rejected $case
$case=Copy-ProgressCase; $case.ProgressPhase='planning'; $case.ProgressPercent=40; Assert-Rejected $case
$case=Copy-ProgressCase; $case.ProgressPercent=100; $case.ProgressPhase='validation'; Assert-Rejected $case
$case=Copy-ProgressCase; $case.ProgressPercent=-1; Assert-Rejected $case
$case=Copy-ProgressCase; $case.ProgressCurrentStepPercent=-1; Assert-Rejected $case
$case=Copy-ProgressCase; $case.ProgressPhase='unknown'; Assert-Rejected $case
foreach($missing in @('ProgressUnderstanding','ProgressCurrentStep','ProgressEvidence','ProgressCurrentAction','ProgressNextGate')){ $case=Copy-ProgressCase; $case[$missing]=''; Assert-Rejected $case }
& $validator -GoalStatus ACTIVE | Out-Null
& $validator -GoalStatus ACTIVE -TerminalFinal -StatusOnly | Out-Null
& $validator -GoalStatus ACTIVE -ImplementationComplete -GoalReviewStarted -GoalReviewChecklistCreated -TaskRegressionReviewStarted | Out-Null
& $validator -GoalStatus ACTIVE -TerminalFinal -UserBeforeFinishCommitmentPending -BeforeFinishClarificationAsked | Out-Null
& $validator @baseUpdate | Out-Null
& $validator -GoalStatus ACTIVE -GoalUpdateReceived -GoalUpdateRoute PRIOR_STEP_CORRECTION -GoalUpdateSummary 'Correct prior contract' -GoalUpdateImpactReason 'Prior output is incomplete' -GoalUpdateAcceptanceCriteria 'Prior step reverified' -GoalUpdatePlanUpdated -ResumePointRecorded -CurrentStepPaused -PriorStepReopened -PriorStepUpdateVerified -ResumePointRestored | Out-Null
& $validator -GoalStatus ACTIVE -GoalUpdateReceived -GoalUpdateRoute FUTURE_STEP -GoalUpdateSummary 'Queue later behavior' -GoalUpdateImpactReason 'Dependency is not ready' -GoalUpdateAcceptanceCriteria 'Future task eventually passes' -GoalUpdatePlanUpdated -CurrentStepPreserved -FutureStepQueued -FutureStepOrder 4 -FutureStepDependencies 'after current validation' | Out-Null
& $validator -GoalStatus ACTIVE -GoalUpdateReceived -GoalUpdateRoute INVALIDATES_CURRENT_WORK -GoalUpdateSummary 'Replace invalid plan' -GoalUpdateImpactReason 'Current work would be wrong' -GoalUpdateAcceptanceCriteria 'Replanned work passes' -GoalUpdatePlanUpdated -ResumePointRecorded -CurrentStepPaused -ReplanCompleted | Out-Null
& $validator -GoalStatus ACTIVE -TerminalFinal -GoalUpdateReceived -GoalUpdateRoute CONFLICT_OR_AMBIGUOUS -GoalUpdateSummary 'Conflicting requirement' -GoalUpdateImpactReason 'Two goals conflict' -GoalUpdateAcceptanceCriteria 'User resolves conflict' -GoalUpdatePlanUpdated -ResumePointRecorded -CurrentStepPreserved -GoalUpdateClarificationAsked | Out-Null
& $validator @validProgress | Out-Null
& $validator -GoalStatus ACTIVE -ProgressUpdate -ProgressPercent 25 -ProgressCurrentStepPercent 80 -ProgressPhase planning -ProgressUnderstanding 'Plan the requested behavior' -ProgressCurrentStep 'Write the specification' -ProgressEvidence 'Owner modules inspected' -ProgressCurrentAction 'Define acceptance criteria' -ProgressNextGate 'Approve the implementation plan' | Out-Null
& $validator -GoalStatus ACTIVE -ProgressUpdate -ProgressPercent 95 -ProgressCurrentStepPercent 100 -ProgressPhase validation -ProgressUnderstanding 'Verify the complete goal' -ProgressCurrentStep 'Run final gates' -ProgressEvidence 'Focused behavior tests passed' -ProgressCurrentAction 'Validate completion evidence' -ProgressNextGate 'Completion audit' | Out-Null
& $validator -GoalStatus COMPLETE -TerminalFinal -RequestedOutcomeSatisfied -GatesPassOrAccepted -VerificationRecorded -CompletionAuditPath $auditPath | Out-Null
& $validator -GoalStatus COMPLETE -TerminalFinal -RequestedOutcomeSatisfied -GatesPassOrAccepted -VerificationRecorded -CompletionAuditPath $auditPath -ProgressPercent 100 -ProgressPhase complete | Out-Null
Assert-Rejected @{GoalStatus='COMPLETE';TerminalFinal=$true;RequestedOutcomeSatisfied=$true;GatesPassOrAccepted=$true;VerificationRecorded=$true;CompletionAuditPath=$auditPath;PostCompletionQuestionAsked=$true}
& $validator -GoalStatus COMPLETE -TerminalFinal -RequestedOutcomeSatisfied -GatesPassOrAccepted -VerificationRecorded -CompletionAuditPath $auditPath -BrowserVerificationRequired -BrowserVerificationPassed -VisualVerificationRequired -VisualVerificationPassed | Out-Null
& $validator -GoalStatus COMPLETE -TerminalFinal -RequestedOutcomeSatisfied -GatesPassOrAccepted -VerificationRecorded -CompletionAuditPath $auditPath -BrowserVerificationRequired -VisualVerificationRequired -VerifiedBrowserEvidenceHandoff -HandoffMatchesCurrentCodeState -ThreadControlChannelDegraded -BrowserFailureStage 'local tab claim' -BrowserFailureReason 'ownership conflict recorded' -BrowserFailureNextAction 'use current verified handoff' -UserFacingStatus 'Chrome recovery: stage=local tab claim; reason=ownership conflict recorded; next=use current verified handoff. Implementation continues.' | Out-Null
& $validator -GoalStatus ACTIVE -ThreadControlChannelDegraded -BrowserFailureStage 'tab discovery' -BrowserFailureReason 'Chrome extension returned no tabs' -BrowserFailureNextAction 'reconnect the existing Chrome binding' -UserFacingStatus 'Chrome recovery: stage=tab discovery; reason=Chrome extension returned no tabs; next=reconnect the existing Chrome binding. Implementation continues.' | Out-Null
$pendingVisual = & $validator -GoalStatus ACTIVE -PendingScreenshotEvidence
if ($pendingVisual.GoalStatus -ne 'ACTIVE' -or $pendingVisual.BlockedAllowed) {
  throw 'Pending browser evidence must keep nonvisual implementation active instead of blocked.'
}
& $validator -GoalStatus BLOCKED -TerminalFinal -BlockerExternalOrUserOnly -NoMeaningfulLocalWorkRemaining -ExternalStateChangeRequired | Out-Null
& $validator -GoalStatus BLOCKED -TerminalFinal -BlockerExternalOrUserOnly -NoMeaningfulLocalWorkRemaining -ExternalStateChangeRequired -BrowserVerificationRequired -ChromeExternallyUnavailable | Out-Null
Write-Host 'Goal lifecycle tests passed'
Remove-Item -LiteralPath $auditPath -Force
