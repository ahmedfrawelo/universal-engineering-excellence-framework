$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$probe=Join-Path $root 'scripts\get-remote-debugging-readiness.ps1'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('ueef-remote-debug-'+[guid]::NewGuid().ToString('N'))
try{
  New-Item -ItemType Directory -Path $temp -Force|Out-Null
  $versionPath=Join-Path $temp 'version.json'; $targetsPath=Join-Path $temp 'targets.json'
  '{"Browser":"Chrome fixture","webSocketDebuggerUrl":"ws://127.0.0.1:9222/devtools/browser/test"}'|Set-Content -LiteralPath $versionPath -Encoding utf8
  '[{"id":"page-1","type":"page","title":"Fixture","url":"http://localhost/","webSocketDebuggerUrl":"ws://127.0.0.1:9222/devtools/page/page-1"}]'|Set-Content -LiteralPath $targetsPath -Encoding utf8
  $notAuthorized=& $probe -VersionJsonPath $versionPath -TargetsJsonPath $targetsPath -Json|ConvertFrom-Json
  if($notAuthorized.status -ne 'NOT_AUTHORIZED'){throw 'Remote debugging became ready without explicit last-resort authorization.'}
  $incomplete=& $probe -AuthorizedLastResort -PriorStageFailure 'chrome-plugin-extension' -VersionJsonPath $versionPath -TargetsJsonPath $targetsPath -Json|ConvertFrom-Json
  if($incomplete.status -ne 'PRIOR_STAGES_INCOMPLETE' -or !@($incomplete.missingStages).Count){throw 'Remote debugging ignored incomplete prior-stage evidence.'}
  $policy=Get-Content -LiteralPath (Join-Path $root 'config\browser-emergency-fallback.json') -Raw|ConvertFrom-Json
  $ready=& $probe -AuthorizedLastResort -PriorStageFailure @($policy.requiredPriorStages) -VersionJsonPath $versionPath -TargetsJsonPath $targetsPath -Json|ConvertFrom-Json
  if($ready.status -ne 'READY_LAST_RESORT' -or $ready.targets -ne 1){throw 'Authorized loopback fixture did not become ready.'}
  $nonLoopbackRejected=$false
  try{& $probe -Endpoint 'http://0.0.0.0:9222' -AuthorizedLastResort -PriorStageFailure @($policy.requiredPriorStages) -VersionJsonPath $versionPath -TargetsJsonPath $targetsPath|Out-Null}catch{$nonLoopbackRejected=$true}
  if(!$nonLoopbackRejected){throw 'Non-loopback remote debugging endpoint was accepted.'}
  Write-Output 'Remote debugging readiness tests passed.'
}finally{if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Recurse -Force}}
