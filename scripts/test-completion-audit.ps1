$ErrorActionPreference='Stop'
$validator=Join-Path $PSScriptRoot 'validate-completion-audit.ps1'
$nodeValidator=Join-Path $PSScriptRoot 'validate-completion-audit.mjs'
function Test-NodeAudit([string]$AuditPath){
  $previousPreference=$ErrorActionPreference
  try{$ErrorActionPreference='SilentlyContinue';& node $nodeValidator $AuditPath *> $null;return $LASTEXITCODE -eq 0}
  finally{$ErrorActionPreference=$previousPreference}
}
$temp=Join-Path ([IO.Path]::GetTempPath()) ('ueef-completion-audit-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp|Out-Null
try{
  $now=[datetimeoffset]::Now.ToString('o')
  $sourceText="Goal: fix the reported behavior.`nConstraint: preserve existing scope."
  $hash=([BitConverter]::ToString(([Security.Cryptography.SHA256]::Create()).ComputeHash([Text.Encoding]::UTF8.GetBytes($sourceText))).Replace('-','')).ToUpperInvariant()
  $valid=[ordered]@{schemaVersion=2;taskId='fixture';auditedAt=$now;requestedOutcome='Observed requested behavior works';sourceReview=[ordered]@{coverageMode='verbatim-segments';sourceText=$sourceText;sourceSha256=$hash;status='PASS';reviewUnits=@([ordered]@{id='RU-1';classification='requirement';sourceQuote='Goal: fix the reported behavior.';start=0;end=32;status='PASS';linkedRequirements=@('REQ-1')},[ordered]@{id='RU-2';classification='constraint';sourceQuote='Constraint: preserve existing scope.';start=33;end=$sourceText.Length;status='PASS';linkedRequirements=@('REQ-1')})};requirements=@([ordered]@{id='REQ-1';text='Fix the reported behavior';status='PASS';acceptanceCriteria=@('AC-1')});acceptanceCriteria=@([ordered]@{id='AC-1';text='Reported behavior is reproduced and then verified fixed';status='PASS';evidence=@([ordered]@{kind='runtime-test';source='fixture';result='PASS';observedAt=$now})});implementationReview=[ordered]@{implementationCompletedAt=$now;goalReviewStartedAt=$now;transitionAnnounced=$true;goalRemainedActiveDuringReview=$true;requestedImplementationStatus='PASS';bestFeasibleOutcomeStatus='PASS';bestFeasibleOutcomeRationale='The requested behavior is satisfied through the canonical owner with focused verification.';status='PASS'};completionChecklist=@([ordered]@{requirementId='REQ-1';sourceReviewUnits=@('RU-1','RU-2');acceptanceCriteria=@('AC-1');requestedImplementationStatus='PASS';bestFeasibleOutcomeStatus='PASS';bestFeasibleOutcomeRationale='The requested behavior and constraint are both satisfied.';checked=$true;status='PASS'});regressionReview=[ordered]@{scope='Changes introduced by this fixture only';changedSurfaces=@('completion validator fixture');checks=@([ordered]@{surface='completion validator fixture';evidence='focused fixture validation';result='PASS'});taskCausedRegressions=@();unrelatedFindings=@();status='PASS'};remainingWork=@();knownProblems=@();limitations=@();conclusion='COMPLETE'}
  $valid['userCommitmentReview']=[ordered]@{explicitBeforeFinishRequestDetected=$false;clarificationAskedBeforeCompletion=$false;resolutionEvidence=@('No explicit before-finish commitment exists in the fixture.');pendingCommitments=@();status='PASS'}
  $valid['goalUpdateReview']=[ordered]@{updatesReceived=0;routes=@();pendingUpdates=@();openResumePoints=@();status='PASS'}
  $valid.implementationReview['goalToImplementationComparisonStatus']='PASS'
  $valid.implementationReview['actualImplementationInventory']=@([ordered]@{id='IMP-1';surface='completion validator fixture';observedBehavior='The requested fixture behavior is validated';evidence='focused completion audit test';linkedRequirements=@('REQ-1');status='PASS'})
  $valid.implementationReview['untracedImplementation']=@()
  $valid.implementationReview['missingImplementation']=@()
  $valid.completionChecklist[0]['actualImplementationIds']=@('IMP-1')
  $valid.completionChecklist[0]['goalToImplementationComparisonStatus']='PASS'
  $valid.goalUpdateReview['allReceivedUpdatesClassified']=$true
  $valid.goalUpdateReview['updateDetectionStatus']='PASS'
  $path=Join-Path $temp 'audit.json';$valid|ConvertTo-Json -Depth 8|Set-Content $path -Encoding utf8
  & $validator -Path $path|Out-Null
  if(!(Test-NodeAudit $path)){throw 'Portable completion validator rejected the valid fixture.'}
  $arabicText=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('2YrYrNioINi52LHYtiDZhtiz2KjYqSDYp9mE2K7Yt9mI2Kkg2KfZhNit2KfZhNmK2Kkg2YjYp9mE2YbYs9io2Kkg2KfZhNmD2YTZitipLg=='))
  $arabicHash=([BitConverter]::ToString(([Security.Cryptography.SHA256]::Create()).ComputeHash([Text.Encoding]::UTF8.GetBytes($arabicText))).Replace('-','')).ToUpperInvariant()
  $arabic=$valid|ConvertTo-Json -Depth 8|ConvertFrom-Json
  $arabic.sourceReview.sourceText=$arabicText
  $arabic.sourceReview.sourceSha256=$arabicHash
  $arabic.sourceReview.reviewUnits=@([pscustomobject]@{id='RU-AR';classification='requirement';sourceQuote=$arabicText;start=0;end=$arabicText.Length;status='PASS';linkedRequirements=@('REQ-1')})
  $arabic.completionChecklist[0].sourceReviewUnits=@('RU-AR')
  [IO.File]::WriteAllText($path,($arabic|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
  & $validator -Path $path|Out-Null
  if(!(Test-NodeAudit $path)){throw 'Portable completion validator rejected the valid Arabic fixture.'}
  foreach($mutation in @('knownProblem','missingEvidence','pendingRequirement','unreviewedGap','hashMismatch','quoteMismatch','missingChecklist','uncheckedRequirement','requestedImplementationFail','bestFeasibleFail','reviewBeforeImplementation','taskRegression','badUnrelatedFinding','pendingCommitment','missedCommitmentQuestion','pendingGoalUpdate','openResumePoint','missingUpdateRoute','missingActualImplementation','comparisonFail','untracedImplementation','missingImplementation','unclassifiedUpdate','invalidAuditTime','futureEvidence','duplicateRequirement','duplicateCriterion')){
    $copy=$valid|ConvertTo-Json -Depth 8|ConvertFrom-Json
    if($mutation -eq 'knownProblem'){$copy.knownProblems=@('reported issue still occurs')}
    if($mutation -eq 'missingEvidence'){$copy.acceptanceCriteria[0].evidence=@()}
    if($mutation -eq 'pendingRequirement'){$copy.requirements[0].status='PENDING'}
    if($mutation -eq 'unreviewedGap'){$copy.sourceReview.reviewUnits[0].start=1}
    if($mutation -eq 'hashMismatch'){$copy.sourceReview.sourceSha256='BAD'}
    if($mutation -eq 'quoteMismatch'){$copy.sourceReview.reviewUnits[0].sourceQuote='tampered'}
    if($mutation -eq 'missingChecklist'){$copy.completionChecklist=@()}
    if($mutation -eq 'uncheckedRequirement'){$copy.completionChecklist[0].checked=$false}
    if($mutation -eq 'requestedImplementationFail'){$copy.implementationReview.requestedImplementationStatus='FAIL'}
    if($mutation -eq 'bestFeasibleFail'){$copy.completionChecklist[0].bestFeasibleOutcomeStatus='FAIL'}
    if($mutation -eq 'reviewBeforeImplementation'){$copy.implementationReview.implementationCompletedAt=[datetimeoffset]::Now.AddMinutes(1).ToString('o')}
    if($mutation -eq 'taskRegression'){$copy.regressionReview.taskCausedRegressions=@('regression remains')}
    if($mutation -eq 'badUnrelatedFinding'){$copy.regressionReview.unrelatedFindings=@([pscustomobject]@{description='historical failure';evidence='';outOfScopeReason=''})}
    if($mutation -eq 'pendingCommitment'){$copy.userCommitmentReview.pendingCommitments=@('User promised an additional requirement before finish.')}
    if($mutation -eq 'missedCommitmentQuestion'){$copy.userCommitmentReview.explicitBeforeFinishRequestDetected=$true;$copy.userCommitmentReview.clarificationAskedBeforeCompletion=$false}
    if($mutation -eq 'pendingGoalUpdate'){$copy.goalUpdateReview.pendingUpdates=@('GU-1')}
    if($mutation -eq 'openResumePoint'){$copy.goalUpdateReview.openResumePoints=@('step-2')}
    if($mutation -eq 'missingUpdateRoute'){$copy.goalUpdateReview.updatesReceived=1}
    if($mutation -eq 'missingActualImplementation'){$copy.completionChecklist[0].actualImplementationIds=@()}
    if($mutation -eq 'comparisonFail'){$copy.completionChecklist[0].goalToImplementationComparisonStatus='FAIL'}
    if($mutation -eq 'untracedImplementation'){$copy.implementationReview.untracedImplementation=@('IMP-X')}
    if($mutation -eq 'missingImplementation'){$copy.implementationReview.missingImplementation=@('REQ-1 behavior absent')}
    if($mutation -eq 'unclassifiedUpdate'){$copy.goalUpdateReview.allReceivedUpdatesClassified=$false}
    if($mutation -eq 'invalidAuditTime'){$copy.auditedAt='not-a-date'}
    if($mutation -eq 'futureEvidence'){$copy.acceptanceCriteria[0].evidence[0].observedAt=[datetimeoffset]::Now.AddMinutes(5).ToString('o')}
    if($mutation -eq 'duplicateRequirement'){$copy.requirements=@($copy.requirements)+@($copy.requirements[0])}
    if($mutation -eq 'duplicateCriterion'){$copy.acceptanceCriteria=@($copy.acceptanceCriteria)+@($copy.acceptanceCriteria[0])}
    $copy|ConvertTo-Json -Depth 8|Set-Content $path -Encoding utf8
    $rejected=$false;try{& $validator -Path $path|Out-Null}catch{$rejected=$true}
    if(!$rejected){throw "Completion audit incorrectly accepted $mutation."}
    if(Test-NodeAudit $path){throw "Portable completion audit incorrectly accepted $mutation."}
  }
}finally{if(Test-Path $temp){Remove-Item $temp -Recurse -Force}}
Write-Host 'Completion audit tests passed'
