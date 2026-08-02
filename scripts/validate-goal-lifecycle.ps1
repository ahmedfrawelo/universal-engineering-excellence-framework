param(
  [ValidateSet('ACTIVE','BLOCKED','COMPLETE')][string]$GoalStatus,
  [switch]$TerminalFinal,
  [switch]$StatusOnly,
  [switch]$BlockerExternalOrUserOnly,
  [switch]$NoMeaningfulLocalWorkRemaining,
  [switch]$ExternalStateChangeRequired,
  [switch]$RequestedOutcomeSatisfied,
  [switch]$RequiredWorkRemaining,
  [switch]$GatesPassOrAccepted,
  [switch]$VerificationRecorded,
  [switch]$BrowserVerificationRequired,
  [switch]$BrowserVerificationPassed,
  [switch]$VisualVerificationRequired,
  [switch]$VisualVerificationPassed,
  [switch]$ThreadControlChannelDegraded,
  [string]$BrowserFailureStage = '',
  [string]$BrowserFailureReason = '',
  [string]$BrowserFailureNextAction = '',
  [switch]$VerifiedBrowserEvidenceHandoff,
  [switch]$HandoffMatchesCurrentCodeState,
  [switch]$ChromeExternallyUnavailable,
  [switch]$UserRestartChromeRequested,
  [switch]$PendingScreenshotEvidence,
  [switch]$ImplementationComplete,
  [switch]$GoalReviewStarted,
  [switch]$GoalReviewChecklistCreated,
  [switch]$TaskRegressionReviewStarted,
  [switch]$PostCompletionQuestionAsked,
  [switch]$UserBeforeFinishCommitmentPending,
  [switch]$BeforeFinishClarificationAsked,
  [switch]$GoalUpdateReceived,
  [ValidateSet('CURRENT_STEP','PRIOR_STEP_CORRECTION','FUTURE_STEP','INVALIDATES_CURRENT_WORK','CONFLICT_OR_AMBIGUOUS','UNKNOWN')][string]$GoalUpdateRoute = 'UNKNOWN',
  [string]$GoalUpdateSummary = '',
  [string]$GoalUpdateImpactReason = '',
  [string]$GoalUpdateAcceptanceCriteria = '',
  [switch]$GoalUpdatePlanUpdated,
  [switch]$ResumePointRecorded,
  [switch]$CurrentStepPreserved,
  [switch]$CurrentStepPaused,
  [switch]$CurrentStepUpdateIntegrated,
  [switch]$PriorStepReopened,
  [switch]$PriorStepUpdateVerified,
  [switch]$ResumePointRestored,
  [switch]$FutureStepQueued,
  [int]$FutureStepOrder = -1,
  [string]$FutureStepDependencies = '',
  [switch]$ReplanCompleted,
  [switch]$GoalUpdateClarificationAsked,
  [int]$ProgressPercent = -1,
  [int]$ProgressCurrentStepPercent = -1,
  [switch]$ProgressUpdate,
  [string]$ProgressUnderstanding = '',
  [string]$ProgressCurrentStep = '',
  [string]$ProgressEvidence = '',
  [string]$ProgressCurrentAction = '',
  [string]$ProgressNextGate = '',
  [string]$CompletionAuditPath = '',
  [ValidateSet('discovery','planning','implementation','validation','release','complete','unknown')][string]$ProgressPhase = 'unknown',
  [string]$UserFacingStatus
)
$ErrorActionPreference = 'Stop'

$completionAuditPassed = $false
if ($GoalStatus -eq 'COMPLETE' -and ![string]::IsNullOrWhiteSpace($CompletionAuditPath)) {
  & (Join-Path $PSScriptRoot 'validate-completion-audit.ps1') -Path $CompletionAuditPath | Out-Null
  $completionAuditPassed = $true
}

$blockedAllowed = $GoalStatus -eq 'BLOCKED' -and $BlockerExternalOrUserOnly -and $NoMeaningfulLocalWorkRemaining -and $ExternalStateChangeRequired
$handoffAllowed = $VerifiedBrowserEvidenceHandoff -and $HandoffMatchesCurrentCodeState
$browserAllowed = !$BrowserVerificationRequired -or $BrowserVerificationPassed -or $handoffAllowed
$visualAllowed = !$VisualVerificationRequired -or $VisualVerificationPassed -or $handoffAllowed
$completeAllowed = $GoalStatus -eq 'COMPLETE' -and $RequestedOutcomeSatisfied -and !$RequiredWorkRemaining -and $GatesPassOrAccepted -and $VerificationRecorded -and $completionAuditPassed -and $browserAllowed -and $visualAllowed
$userInputWaitAllowed = $UserBeforeFinishCommitmentPending -and $GoalStatus -eq 'ACTIVE' -and $BeforeFinishClarificationAsked
$goalUpdateClarificationWaitAllowed = $GoalUpdateReceived -and $GoalUpdateRoute -eq 'CONFLICT_OR_AMBIGUOUS' -and $GoalStatus -eq 'ACTIVE' -and $GoalUpdateClarificationAsked -and $ResumePointRecorded -and $CurrentStepPreserved
$terminalAllowed = $StatusOnly -or $completeAllowed -or $blockedAllowed -or $userInputWaitAllowed -or $goalUpdateClarificationWaitAllowed
$implementationTransitionAllowed = $ImplementationComplete -and $GoalStatus -eq 'ACTIVE' -and $GoalReviewStarted -and $GoalReviewChecklistCreated -and $TaskRegressionReviewStarted

if ($GoalStatus -eq 'BLOCKED' -and !$blockedAllowed) { throw 'Invalid BLOCKED transition.' }
if ($GoalStatus -eq 'BLOCKED' -and $BrowserVerificationRequired -and !$ChromeExternallyUnavailable) { throw 'Browser verification requirement is not a valid BLOCKED transition without independent Chrome unavailability evidence.' }
if ($GoalStatus -eq 'BLOCKED' -and $ThreadControlChannelDegraded -and !$ChromeExternallyUnavailable) { throw 'Thread-local browser control degradation is not a valid BLOCKED transition.' }
if ($GoalStatus -eq 'BLOCKED' -and $PendingScreenshotEvidence) { throw 'Pending screenshot evidence is not a valid BLOCKED transition.' }
if ($UserRestartChromeRequested -and !$ChromeExternallyUnavailable) { throw 'A Chrome restart request requires independent Chrome unavailability evidence.' }
if ($ImplementationComplete -and !$implementationTransitionAllowed) { throw 'Implementation completion must transition immediately to goal review with a checklist and task-regression review while GoalStatus remains ACTIVE.' }
if ($PostCompletionQuestionAsked -and $GoalStatus -eq 'COMPLETE') { throw 'After the goal is complete, stop; do not ask whether anything is missing or whether more work is wanted.' }
if ($UserBeforeFinishCommitmentPending -and !$userInputWaitAllowed) { throw 'An explicit before-finish user commitment keeps the goal ACTIVE and requires asking the user for the promised detail before completion.' }
if ($GoalUpdateReceived) {
  foreach($field in @(@{name='summary';value=$GoalUpdateSummary},@{name='impact reason';value=$GoalUpdateImpactReason},@{name='acceptance criteria';value=$GoalUpdateAcceptanceCriteria})) { if([string]::IsNullOrWhiteSpace([string]$field.value)){throw "Goal updates require a substantive $($field.name)."} }
  if($GoalUpdateRoute -eq 'UNKNOWN' -or !$GoalUpdatePlanUpdated){throw 'Goal updates require an explicit route and an updated plan.'}
  switch($GoalUpdateRoute){
    'CURRENT_STEP' { if(!$CurrentStepPreserved -or !$CurrentStepUpdateIntegrated){throw 'A current-step goal update must be integrated into the current step without abandoning it.'} }
    'PRIOR_STEP_CORRECTION' { if(!$ResumePointRecorded -or !$CurrentStepPaused -or !$PriorStepReopened -or !$PriorStepUpdateVerified -or !$ResumePointRestored){throw 'A prior-step correction requires a saved resume point, verified correction, and return to the interrupted current step.'} }
    'FUTURE_STEP' { if(!$CurrentStepPreserved -or !$FutureStepQueued -or $FutureStepOrder -lt 1 -or [string]::IsNullOrWhiteSpace($FutureStepDependencies)){throw 'A future-step goal update must preserve current work and be queued with order and dependencies.'} }
    'INVALIDATES_CURRENT_WORK' { if(!$ResumePointRecorded -or !$CurrentStepPaused -or !$ReplanCompleted){throw 'An update that invalidates current work requires a saved resume point, safe pause, and completed replan.'} }
    'CONFLICT_OR_AMBIGUOUS' { if(!$goalUpdateClarificationWaitAllowed){throw 'A conflicting or ambiguous goal update must preserve a resume point and ask the user while the goal remains ACTIVE.'} }
  }
}
if ($ThreadControlChannelDegraded -and !$ChromeExternallyUnavailable) {
  foreach($field in @(@{name='stage';value=$BrowserFailureStage},@{name='reason';value=$BrowserFailureReason},@{name='next';value=$BrowserFailureNextAction})) { if([string]::IsNullOrWhiteSpace([string]$field.value)){throw "Thread-local browser degradation requires a recorded $($field.name)."} }
  if($BrowserFailureReason -match '(?i)password|cookie|storage|token|secret|stack\s*trace'){throw 'Browser failure reason must not expose secrets, storage, or raw stack traces.'}
  $expectedRecoveryStatus="Chrome recovery: stage=$BrowserFailureStage; reason=$BrowserFailureReason; next=$BrowserFailureNextAction. Implementation continues."
  if($UserFacingStatus -ne $expectedRecoveryStatus){throw 'Thread-local browser degradation requires the structured stage/reason/next recovery status.'}
}
if (($BrowserVerificationRequired -or $VisualVerificationRequired) -and $VerifiedBrowserEvidenceHandoff -and !$HandoffMatchesCurrentCodeState) { throw 'Browser evidence handoff does not cover the current code state.' }
if ($ProgressPercent -gt 100) { throw 'Progress percent cannot exceed 100.' }
if ($ProgressCurrentStepPercent -gt 100) { throw 'Current-step progress percent cannot exceed 100.' }
if ($ProgressUpdate -and $ProgressPercent -lt 0) { throw 'Progress updates require an explicit conservative overall percentage.' }
if ($ProgressUpdate -and $ProgressCurrentStepPercent -lt 0) { throw 'Progress updates require an explicit current-step percentage.' }
if ($ProgressUpdate -and $ProgressPhase -eq 'unknown') { throw 'Progress updates require an explicit phase.' }
if ($ProgressPercent -eq 100 -and $GoalStatus -ne 'COMPLETE') { throw 'Progress cannot be 100 before the goal is complete.' }
if ($ProgressPhase -in @('discovery','planning') -and $ProgressPercent -gt 30) { throw 'Discovery or planning progress cannot exceed 30 percent.' }
if ($ProgressPhase -eq 'implementation' -and $ProgressPercent -gt 75) { throw 'Implementation progress cannot exceed 75 percent before validation.' }
if ($ProgressPhase -in @('validation','release') -and $ProgressPercent -gt 95 -and $GoalStatus -ne 'COMPLETE') { throw 'Validation or release progress cannot exceed 95 percent before completion.' }
if ($ProgressUpdate) {
  foreach ($field in @(
    @{name='understanding';value=$ProgressUnderstanding},
    @{name='current step';value=$ProgressCurrentStep},
    @{name='new evidence';value=$ProgressEvidence},
    @{name='current action';value=$ProgressCurrentAction},
    @{name='next gate';value=$ProgressNextGate}
  )) {
    if ([string]::IsNullOrWhiteSpace([string]$field.value)) { throw "Progress updates require a non-empty $($field.name)." }
  }
}
if ($GoalStatus -eq 'COMPLETE' -and !$completeAllowed) { throw 'Invalid COMPLETE transition.' }
if ($TerminalFinal -and !$terminalAllowed) { throw 'Terminal final response is forbidden for this goal state.' }

[pscustomobject]@{ GoalStatus=$GoalStatus; TerminalFinalAllowed=$terminalAllowed; BlockedAllowed=$blockedAllowed; CompleteAllowed=$completeAllowed; CompletionAuditPassed=$completionAuditPassed; BrowserVerificationAllowed=$browserAllowed; VisualVerificationAllowed=$visualAllowed; EvidenceHandoffAllowed=$handoffAllowed; ImplementationTransitionAllowed=$implementationTransitionAllowed; UserInputWaitAllowed=$userInputWaitAllowed; GoalUpdateRouteAllowed=(!$GoalUpdateReceived -or $GoalUpdateRoute -ne 'UNKNOWN'); GoalUpdateRoute=$GoalUpdateRoute; ProgressPercent=$ProgressPercent; ProgressCurrentStepPercent=$ProgressCurrentStepPercent; ProgressPhase=$ProgressPhase; ProgressUpdate=$ProgressUpdate.IsPresent }
