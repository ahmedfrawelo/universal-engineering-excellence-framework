[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Task,
  [ValidateRange(0,3)][int]$Scope = 0,
  [ValidateRange(0,3)][int]$Ambiguity = 0,
  [ValidateRange(0,3)][int]$Coupling = 0,
  [ValidateRange(0,3)][int]$Risk = 0,
  [ValidateRange(0,3)][int]$Verification = 0,
  [ValidateSet('None','Architecture','Authentication','Authorization','Security','Production','Migration','Destructive','Privacy','Payment','Incident','Release')][string]$RiskFloor = 'None',
  [ValidateSet('ui','browser','current-docs','ambiguous','debugging')][string[]]$TaskTag = @(),
  [switch]$CodeChange,
  [switch]$IncludeHealth,
  [switch]$SkipHealth,
  [switch]$Json
)
$ErrorActionPreference = 'Stop'
$inputParameters = @{} + $PSBoundParameters
$classificationArgs = @{ Task=$Task; Json=$true }
foreach ($name in @('Scope','Ambiguity','Coupling','Risk','Verification','RiskFloor','TaskTag','CodeChange')) {
  if ($inputParameters.ContainsKey($name)) { $classificationArgs[$name] = $inputParameters[$name] }
}
$classification = (& (Join-Path $PSScriptRoot 'get-ueef-task-classification.ps1') @classificationArgs | Out-String) | ConvertFrom-Json
$route = $classification.route
$profile = (& (Join-Path $PSScriptRoot 'select-capability-profile.ps1') -Task $Task -TaskTag $classification.values.taskTags -RouteTier $route.tier -RiskFloor $classification.values.riskFloor -CodeChange:([bool]$classification.values.codeChange) -ClassificationSource $classification.source -FrontendRoute $classification.frontendRoute -Json | Out-String) | ConvertFrom-Json

$repositoryPath = Split-Path -Parent $PSScriptRoot
$runtimeStatus = (& (Join-Path $PSScriptRoot 'ueef-status.ps1') -RepositoryPath $repositoryPath -SkipRuntimeDrift -Json | Out-String) | ConvertFrom-Json
$activationMode = if ($runtimeStatus.mode -eq 'managed-runtime' -and $runtimeStatus.overall -eq 'ACTIVE') {
  'ACTIVE_RUNTIME'
} elseif ($runtimeStatus.mode -eq 'source-checkout' -and $runtimeStatus.overall -eq 'SOURCE_VALIDATED') {
  'SOURCE_VALIDATED'
} else {
  'INACTIVE'
}
$executionAuthorized = $activationMode -in @('ACTIVE_RUNTIME','SOURCE_VALIDATED')

$healthRequired = $IncludeHealth.IsPresent -or $profile.capabilityHealthRequired
$health = $null
if ($healthRequired -and !$SkipHealth) {
  $raw = & (Join-Path $PSScriptRoot 'get-ueef-health.ps1') -RepositoryPath $repositoryPath -Json 2>$null | Out-String
  if ($raw) { $health = $raw | ConvertFrom-Json }
}
$status = if (!$executionAuthorized) {
  'BLOCKED'
} elseif ($health -and $health.overall.status -eq 'FAIL') {
  'BLOCKED'
} elseif ($healthRequired -and !$health) {
  'READY_WITH_FALLBACK'
} else {
  'READY'
}
$browserGate = $null
if ($classification.values.taskTags -contains 'browser') {
  $browserGate = [ordered]@{
    status = 'REQUIRED'
    enforcement = 'HARD_FAIL_BEFORE_BROWSER_TOOL'
    requiredBeforeTool = @(
      'Read the installed Chrome control skill for the current host.',
      'Select the Chrome family explicitly through the installed skill; never use a default selector that may choose the in-app browser.',
      'On Claude hosts, bootstrap browser-client.mjs only through mcp__node_repl__js, then use the Chrome extension binding.',
      'Enumerate user.openTabs() to prove the existing Chrome window/profile/session, then create one dedicated task tab through that same binding and claim the exact created object. Reuse a user tab only by explicit request.',
      'Never launch Playwright MCP, IDE Simple Browser, in-app browser, browser.newContext, or browser.launch as a substitute.',
      'Treat Chrome DevTools/CDP as AUTHORIZED_LOOPBACK_LAST_RESORT only after every configured prior stage failed, explicit user authorization, and READY_LAST_RESORT from the readiness probe; stricter host rules win.'
    )
    allowedPath = @('Codex Chrome control plugin', 'mcp__node_repl__js', 'agent.browsers.get("chrome") or current skill Chrome-family selector', 'full Chrome binding documentation', 'user.openTabs() session proof', 'dedicated task tab in same window/profile/session', 'claim exact created tab', 'claimed tab.playwright', 'authorized loopback CDP on the same existing target')
    forbiddenSurfaces = @('agent.browsers.getDefault()', 'agent.browsers.getForUrl()', 'agent.browsers.get("iab")', 'mcp__playwright__*', 'mcp__chrome_devtools__* outside AUTHORIZED_LOOPBACK_LAST_RESORT', 'browser_*', 'Cursor/IDE Simple Browser', 'in-app browser', 'browser.newContext', 'browser.launch', 'second browser', 'new window', 'new session', 'new panel', 'temporary profile', 'isolated context', 'non-loopback CDP', 'cookie/storage/profile inspection')
    taskTabPolicy = [ordered]@{default='DEDICATED_TAB_SAME_CHROME_WINDOW_PROFILE_SESSION';reuseExistingTab='EXPLICIT_USER_REQUEST_ONLY';preserveUserActiveTab=$true;newWindowAllowed=$false;newSessionAllowed=$false;inAppBrowserAllowed=$false}
    failureReporting = [ordered]@{requiredFields=@('stage','reason','next');template='Chrome recovery: stage=<stage>; reason=<reason>; next=<next>. Implementation continues.';genericChannelFailureForbidden=$true;rawStackTraceForbidden=$true;repeatWithoutNewEvidenceForbidden=$true}
    emergencyFallback = [ordered]@{status='EXPLICIT_LAST_RESORT_ONLY';policy='config/browser-emergency-fallback.json';probe='scripts/get-remote-debugging-readiness.ps1 -AuthorizedLastResort -PriorStageFailure <recorded-stages> -ExpectedTargetId <dedicated-target-id>';requiredResult='READY_LAST_RESORT';incompleteResult='PRIOR_STAGES_INCOMPLETE';requiresUserAuthorization=$true;requiresAllPriorStageEvidence=$true;requiresExactTargetId=$true;hostRulesWin=$true}
    failureAction = 'Do not select or call a browser tool outside allowedPath and do not invent another surface. Report stage, reason, evidence, and next action. After recorded prior-stage failures, request or consume explicit authorization for AUTHORIZED_LOOPBACK_LAST_RESORT; an alternative never means the in-app browser.'
  }
}
$result = [ordered]@{
  schemaVersion = 4
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  status = $status
  task = $Task
  classification = $classification
  activation = [ordered]@{
    mode = $activationMode
    executionAuthorized = $executionAuthorized
    runtimeMode = $runtimeStatus.mode
    runtimeOverall = $runtimeStatus.overall
    status = $runtimeStatus
  }
  profile = $profile
  health = [ordered]@{
    required = $healthRequired
    checked = [bool]$health
    status = if($health){$health.overall.status}else{'SKIPPED'}
    report = $health
  }
  browserGate = $browserGate
  progressReporting = [ordered]@{
    appliesWhen = 'MULTI_STEP_ACTIVE_GOAL_MATERIAL_MILESTONE'
    requiredFields = @('understanding','phase','currentStep','currentStepPercent','overallPercent','newEvidence','currentAction','nextGate')
    currentStepPercentScope = 'NAMED_CURRENT_STEP_ONLY'
    overallPercentScope = 'FULL_CURRENT_GOAL_AND_PLAN_CONSERVATIVE'
    percentagesAreIndependent = $true
    activeGoalOverallMaximum = 95
    validator = 'scripts/validate-goal-lifecycle.ps1 -ProgressUpdate'
  }
  completionReview = [ordered]@{
    implementationTransition = 'IMPLEMENTATION_COMPLETE_TO_GOAL_REVIEW_STARTED'
    goalStatusDuringReview = 'ACTIVE'
    requiredChecklistFields = @('requirementId','sourceReviewUnits','acceptanceCriteria','actualImplementationIds','requestedImplementationStatus','bestFeasibleOutcomeStatus','goalToImplementationComparisonStatus','bestFeasibleOutcomeRationale','checked','status')
    regressionScope = 'TASK_CHANGED_SURFACES_ONLY'
    taskCausedRegressionAction = 'FIX_AND_RERUN_AFFECTED_REVIEW'
    unrelatedFindingAction = 'RECORD_WITH_EVIDENCE_AND_OUT_OF_SCOPE_REASON_DO_NOT_FIX'
    completedGoalFinalAction = 'STATE_GOAL_COMPLETE_AND_STOP_WITHOUT_FOLLOW_UP_QUESTION'
    beforeFinishCommitmentAction = 'KEEP_ACTIVE_ASK_USER_RESOLVE_BEFORE_COMPLETE'
    beforeFinishCommitmentAudit = 'NO_PENDING_COMMITMENTS_AND_RESOLUTION_EVIDENCE_REQUIRED'
    actualImplementationComparison = 'EVERY_REQUIREMENT_TO_ACTUAL_IMPLEMENTATION_AND_EVIDENCE'
    reverseTrace = 'NO_UNTRACED_IMPLEMENTATION'
    validator = 'scripts/validate-completion-audit.ps1'
  }
  goalUpdateRouting = [ordered]@{
    routes = @('CURRENT_STEP','PRIOR_STEP_CORRECTION','FUTURE_STEP','INVALIDATES_CURRENT_WORK','CONFLICT_OR_AMBIGUOUS')
    currentStepAction = 'MERGE_AND_CONTINUE_CURRENT_STEP'
    priorStepAction = 'SAVE_RESUME_POINT_REOPEN_VERIFY_RESTORE'
    futureStepAction = 'QUEUE_WITH_ORDER_DEPENDENCIES_ACCEPTANCE_CRITERIA'
    invalidationAction = 'SAVE_RESUME_POINT_PAUSE_SAFE_REPLAN'
    conflictAction = 'PRESERVE_STATE_ASK_USER'
    completionInvariant = 'NO_PENDING_UPDATES_OR_OPEN_RESUME_POINTS'
    updateDetection = 'EVERY_RECEIVED_UPDATE_DETECTED_AND_CLASSIFIED'
    missingImplementationAction = 'KEEP_ACTIVE_IMPLEMENT_IN_ROUTED_STEP_REPEAT_COMPARISON'
    validator = 'scripts/validate-goal-lifecycle.ps1 -GoalUpdateReceived'
  }
  decisions = @($profile.workflowDecisions)
}
if ($Json) { $result | ConvertTo-Json -Depth 10 } else { Write-Output "UEEF task preflight: $status"; Write-Output "Route: $($route.tier)"; Write-Output "Profile: $($profile.profile)"; Write-Output "Health: $($result.health.status)" }
if ($status -eq 'BLOCKED') { exit 1 }
