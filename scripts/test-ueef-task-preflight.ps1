$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$preflight = Join-Path $PSScriptRoot 'get-ueef-task-preflight.ps1'
$ui = (& $preflight -Task 'Contradictory prose: do not design' -TaskTag ui -Scope 1 -CodeChange -Json | Out-String) | ConvertFrom-Json
if ($ui.status -ne 'READY' -or $ui.classification.route.tier -ne 'T1' -or $ui.profile.frontendMode -ne 'Quick' -or $ui.profile.skills -notcontains 'typeui-fundamentals' -or $ui.profile.skills -contains 'ui-ux-pro-max' -or $ui.profile.skills -contains 'impeccable' -or $ui.profile.workflows -notcontains 'evidence-loop') { throw 'Explicit UI preflight contract failed.' }
if ($null -eq $ui.classification.frontendRoute -or !$ui.classification.frontendRoute.applies) { throw 'Preflight must preserve the single canonical frontend-route result.' }
if (!$ui.activation.executionAuthorized) { throw 'Preflight must authorize a validated source checkout or active managed runtime.' }
if ($ui.activation.runtimeMode -eq 'source-checkout') {
  if ($ui.activation.mode -ne 'SOURCE_VALIDATED' -or $ui.activation.runtimeOverall -ne 'SOURCE_VALIDATED') { throw 'Source preflight must report SOURCE_VALIDATED.' }
} elseif ($ui.activation.runtimeMode -eq 'managed-runtime') {
  if ($ui.activation.mode -ne 'ACTIVE_RUNTIME' -or $ui.activation.runtimeOverall -ne 'ACTIVE') { throw 'Installed runtime preflight must report ACTIVE_RUNTIME.' }
} else {
  throw "Unexpected preflight runtime mode: $($ui.activation.runtimeMode)"
}
if ($ui.schemaVersion -ne 4 -or (@($ui.progressReporting.requiredFields) -join ',') -ne 'understanding,phase,currentStep,currentStepPercent,overallPercent,newEvidence,currentAction,nextGate' -or !$ui.progressReporting.percentagesAreIndependent -or $ui.progressReporting.activeGoalOverallMaximum -ne 95) { throw 'Preflight dual-percentage progress contract is incomplete.' }
if ($ui.completionReview.goalStatusDuringReview -ne 'ACTIVE' -or (@($ui.completionReview.requiredChecklistFields) -join ',') -notmatch 'requestedImplementationStatus.*bestFeasibleOutcomeStatus.*checked' -or $ui.completionReview.taskCausedRegressionAction -ne 'FIX_AND_RERUN_AFFECTED_REVIEW' -or $ui.completionReview.unrelatedFindingAction -notmatch 'DO_NOT_FIX' -or $ui.completionReview.completedGoalFinalAction -notmatch 'STOP_WITHOUT_FOLLOW_UP_QUESTION') { throw 'Preflight implementation-to-completion review contract is incomplete.' }
if($ui.completionReview.beforeFinishCommitmentAction -ne 'KEEP_ACTIVE_ASK_USER_RESOLVE_BEFORE_COMPLETE' -or $ui.completionReview.beforeFinishCommitmentAudit -notmatch 'NO_PENDING_COMMITMENTS'){throw 'Preflight before-finish user commitment contract is incomplete.'}
if($ui.completionReview.actualImplementationComparison -notmatch 'ACTUAL_IMPLEMENTATION_AND_EVIDENCE' -or $ui.completionReview.reverseTrace -ne 'NO_UNTRACED_IMPLEMENTATION' -or (@($ui.completionReview.requiredChecklistFields) -join ',') -notmatch 'actualImplementationIds.*goalToImplementationComparisonStatus'){throw 'Preflight actual implementation comparison contract is incomplete.'}
if((@($ui.goalUpdateRouting.routes) -join ',') -ne 'CURRENT_STEP,PRIOR_STEP_CORRECTION,FUTURE_STEP,INVALIDATES_CURRENT_WORK,CONFLICT_OR_AMBIGUOUS' -or $ui.goalUpdateRouting.priorStepAction -notmatch 'RESUME_POINT.*RESTORE' -or $ui.goalUpdateRouting.futureStepAction -notmatch 'ORDER_DEPENDENCIES_ACCEPTANCE_CRITERIA' -or $ui.goalUpdateRouting.completionInvariant -notmatch 'NO_PENDING_UPDATES' -or $ui.goalUpdateRouting.updateDetection -notmatch 'EVERY_RECEIVED_UPDATE' -or $ui.goalUpdateRouting.missingImplementationAction -notmatch 'REPEAT_COMPARISON'){throw 'Preflight goal update routing contract is incomplete.'}
$browser = (& $preflight -Task 'Inspect browser' -TaskTag browser -SkipHealth -Json | Out-String) | ConvertFrom-Json
if (!$browser.health.required -or $browser.health.checked) { throw 'Browser preflight must require but not probe health when explicitly skipped.' }
if ($browser.browserGate.status -ne 'REQUIRED' -or $browser.browserGate.enforcement -ne 'HARD_FAIL_BEFORE_BROWSER_TOOL') { throw 'Browser preflight must emit the mandatory hard-fail browser gate.' }
if ($browser.browserGate.allowedPath -notcontains 'Codex Chrome control plugin' -or $browser.browserGate.allowedPath -notcontains 'mcp__node_repl__js' -or $browser.browserGate.allowedPath -notcontains 'dedicated task tab in same window/profile/session' -or $browser.browserGate.forbiddenSurfaces -notcontains 'agent.browsers.get("iab")' -or $browser.browserGate.forbiddenSurfaces -notcontains 'browser.launch') { throw 'Browser preflight gate allowlist or forbidden surfaces are incomplete.' }
if($browser.browserGate.taskTabPolicy.default -ne 'DEDICATED_TAB_SAME_CHROME_WINDOW_PROFILE_SESSION' -or !$browser.browserGate.taskTabPolicy.preserveUserActiveTab -or $browser.browserGate.taskTabPolicy.inAppBrowserAllowed){throw 'Browser preflight dedicated-tab policy is incomplete.'}
if(!$browser.browserGate.emergencyFallback.requiresExactTargetId -or $browser.browserGate.emergencyFallback.probe -notmatch 'ExpectedTargetId'){throw 'Browser emergency fallback does not require exact same-target proof.'}
if(@($browser.browserGate.failureReporting.requiredFields) -join ',' -ne 'stage,reason,next' -or !$browser.browserGate.failureReporting.genericChannelFailureForbidden){throw 'Browser failure-reporting contract is incomplete.'}
if ($browser.browserGate.failureAction -notmatch 'Do not select or call a browser tool') { throw 'Browser preflight must stop tool selection before the gate is resolved.' }
$nonBrowser = (& $preflight -Task 'Document the browser policy in this repository' -SkipHealth -Json | Out-String) | ConvertFrom-Json
if ($null -ne $nonBrowser.browserGate -or $nonBrowser.profile.mcps -contains 'node_repl') { throw 'A docs task that merely mentions a browser must not require browser control.' }
$debug = (& $preflight -Task 'Fix regression' -TaskTag debugging -Scope 2 -Risk 2 -Verification 2 -RiskFloor Security -CodeChange -Json | Out-String) | ConvertFrom-Json
if ($debug.classification.route.tier -ne 'T3' -or $debug.profile.profile -ne 'ASSURED' -or $debug.profile.workflows -notcontains 'systematic-debugging' -or $debug.profile.workflows -notcontains 'independent-review') { throw 'Assured debugging preflight contract failed.' }
$narrowRepository = (& $preflight -Task 'Rename one local variable' -ProjectRoot $root -SkipHealth -Json | Out-String) | ConvertFrom-Json
if ($narrowRepository.repositoryIntelligence.selected -or $narrowRepository.repositoryIntelligence.action -ne 'NONE') { throw 'Narrow task incorrectly selected repository intelligence.' }
$broadRepository = (& $preflight -Task 'Audit architecture and affected dependencies across this repository' -ProjectRoot $root -Scope 2 -RiskFloor Architecture -SkipHealth -Json | Out-String) | ConvertFrom-Json
if (!$broadRepository.repositoryIntelligence.selected -or !$broadRepository.repositoryIntelligence.enforced -or $broadRepository.repositoryIntelligence.action -notin @('USED_FRESH','REFRESHED_AND_USED','BUILT_AND_USED') -or $broadRepository.repositoryIntelligence.queryReport.status -notin @('PASS','NO_MATCH')) { throw 'Broad architecture task did not build or reuse and then use repository intelligence.' }
$missingGraphFixture = Join-Path ([IO.Path]::GetTempPath()) ('ueef-preflight-graph-' + [guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory -Path (Join-Path $missingGraphFixture 'src') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $missingGraphFixture 'src\service.py') -Encoding utf8 -Value 'def architecture_owner(): return "ready"'
  $builtRepository = (& $preflight -Task 'Audit architecture ownership across this repository' -ProjectRoot $missingGraphFixture -Scope 2 -RiskFloor Architecture -SkipHealth -Json | Out-String) | ConvertFrom-Json
  if ($builtRepository.status -notin @('READY','READY_WITH_FALLBACK') -or $builtRepository.repositoryIntelligence.action -ne 'BUILT_AND_USED' -or $builtRepository.repositoryIntelligence.queryReport.status -notin @('PASS','NO_MATCH')) { throw 'Selected repository intelligence was not automatically built and used when missing.' }
  foreach ($artifact in @('graph.json','GRAPH_REPORT.md','graph.html','state.json')) {
    if (!(Test-Path -LiteralPath (Join-Path $missingGraphFixture ".ueef\repository-graph\$artifact") -PathType Leaf)) { throw "Automatic repository-intelligence build omitted $artifact." }
  }
} finally {
  if (Test-Path -LiteralPath $missingGraphFixture) { Remove-Item -LiteralPath $missingGraphFixture -Recurse -Force }
}

# A preflight owns one canonical frontend-route evaluation. Other Node-backed
# routes (including dynamic model routing) are allowed, so the shim records
# arguments and counts the canonical frontend selector specifically.
$nodeCommand = (Get-Command node -ErrorAction Stop).Source
$shimRoot = Join-Path ([IO.Path]::GetTempPath()) ('ueef-node-count-' + [guid]::NewGuid().ToString('N'))
$countFile = Join-Path $shimRoot 'count.txt'
$previousPath = $env:PATH
$previousCountFile = $env:UEEF_NODE_COUNT_FILE
try {
  New-Item -ItemType Directory -Path $shimRoot -Force | Out-Null
@"
@echo off
>>"%UEEF_NODE_COUNT_FILE%" echo %*
"$nodeCommand" %*
"@ | Set-Content -LiteralPath (Join-Path $shimRoot 'node.cmd') -Encoding ascii
  $env:UEEF_NODE_COUNT_FILE = $countFile
  $env:PATH = $shimRoot + [IO.Path]::PathSeparator + $previousPath
  $singlePass = (& $preflight -Task 'Build an Angular data grid dashboard' -SkipHealth -Json | Out-String) | ConvertFrom-Json
  $frontendInvocations = if (Test-Path -LiteralPath $countFile) { @((Get-Content -LiteralPath $countFile) | Where-Object { $_ -match 'select-frontend-route\.mjs' }).Count } else { 0 }
  if ($singlePass.status -ne 'READY' -or $frontendInvocations -ne 1) { throw "Preflight must evaluate the canonical frontend route exactly once; observed $frontendInvocations canonical calls." }
} finally {
  $env:PATH = $previousPath
  $env:UEEF_NODE_COUNT_FILE = $previousCountFile
  if (Test-Path -LiteralPath $shimRoot) { Remove-Item -LiteralPath $shimRoot -Recurse -Force }
}
Write-Host 'UEEF task preflight tests passed'
