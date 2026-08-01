$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$generator=Join-Path $root 'scripts\new-task-evidence.ps1'
$validator=Join-Path $root 'scripts\validate-task-evidence.ps1'
$temp=Join-Path ([IO.Path]::GetTempPath()) ("ueef-generated-evidence-"+[guid]::NewGuid().ToString('N')+'.json')
try {
  & $generator -TaskId 'generator-test' -Tier T3 -RepositoryRoot $root -SelectedGate @('architecture-gate.md','performance-gate.md') -OutputPath $temp | Out-Null
  $artifact=Get-Content -LiteralPath $temp -Raw | ConvertFrom-Json
  foreach($domain in @('architecture','file-organization','performance')) { if($domain -notin @($artifact.selectedDomains)){throw "Generated evidence omitted $domain."} }
  if(@($artifact.domains.architecture.fields.PSObject.Properties.Name).Count -ne 9){throw 'Generated Architecture fields do not match the registry.'}
  $rejected=$false
  try { & $validator -Tier T3 -SelectedDomain performance -EvidencePath $temp | Out-Null } catch { $rejected=$true }
  if(!$rejected){throw 'Generated placeholders were incorrectly accepted.'}
  $overwriteRejected=$false
  try { & $generator -TaskId 'overwrite' -Tier T3 -RepositoryRoot $root -SelectedDomain testing -OutputPath $temp | Out-Null } catch { $overwriteRejected=$true }
  if(!$overwriteRejected){throw 'Generator overwrote evidence without -Force.'}
  Write-Output 'Task evidence generator tests passed.'
} finally { if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Force} }
