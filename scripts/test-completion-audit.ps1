$ErrorActionPreference='Stop'
$validator=Join-Path $PSScriptRoot 'validate-completion-audit.ps1'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('ueef-completion-audit-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp|Out-Null
try{
  $now=[datetimeoffset]::Now.ToString('o')
  $valid=[ordered]@{schemaVersion=1;taskId='fixture';auditedAt=$now;requestedOutcome='Observed requested behavior works';requirements=@([ordered]@{id='REQ-1';text='Fix the reported behavior';status='PASS';acceptanceCriteria=@('AC-1')});acceptanceCriteria=@([ordered]@{id='AC-1';text='Reported behavior is reproduced and then verified fixed';status='PASS';evidence=@([ordered]@{kind='runtime-test';source='fixture';result='PASS';observedAt=$now})});remainingWork=@();knownProblems=@();limitations=@();conclusion='COMPLETE'}
  $path=Join-Path $temp 'audit.json';$valid|ConvertTo-Json -Depth 8|Set-Content $path -Encoding utf8
  & $validator -Path $path|Out-Null
  foreach($mutation in @('knownProblem','missingEvidence','pendingRequirement')){
    $copy=$valid|ConvertTo-Json -Depth 8|ConvertFrom-Json
    if($mutation -eq 'knownProblem'){$copy.knownProblems=@('reported issue still occurs')}
    if($mutation -eq 'missingEvidence'){$copy.acceptanceCriteria[0].evidence=@()}
    if($mutation -eq 'pendingRequirement'){$copy.requirements[0].status='PENDING'}
    $copy|ConvertTo-Json -Depth 8|Set-Content $path -Encoding utf8
    $rejected=$false;try{& $validator -Path $path|Out-Null}catch{$rejected=$true}
    if(!$rejected){throw "Completion audit incorrectly accepted $mutation."}
  }
}finally{if(Test-Path $temp){Remove-Item $temp -Recurse -Force}}
Write-Host 'Completion audit tests passed'
