[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ProjectPath,
  [Parameter(Mandatory)][ValidateRange(1,65535)][int]$Port,
  [string]$HealthUri = '',
  [string]$ExpectedContent = '',
  [ValidateSet('Auto','ListeningHealthy','ListeningUnhealthy','NotListening')][string]$ProbeState = 'Auto',
  [switch]$AllowSyntheticProbe,
  [switch]$SyntheticOwnershipProven,
  [switch]$Json
)
$ErrorActionPreference='Stop'
$project=(Resolve-Path -LiteralPath $ProjectPath).Path
if($ProbeState -ne 'Auto' -and !$AllowSyntheticProbe){throw 'Synthetic service probe states are test-only and require -AllowSyntheticProbe.'}
if($SyntheticOwnershipProven -and !$AllowSyntheticProbe){throw 'Synthetic ownership proof is test-only and requires -AllowSyntheticProbe.'}

function Test-Listening([int]$TargetPort){
  $client=[Net.Sockets.TcpClient]::new()
  try{
    $connect=$client.ConnectAsync('127.0.0.1',$TargetPort)
    return $connect.Wait(800) -and $client.Connected
  }catch{return $false}finally{$client.Dispose()}
}

$listening=if($ProbeState -eq 'Auto'){Test-Listening $Port}else{$ProbeState -ne 'NotListening'}
$ownershipProven=$false;$ownershipDetail='not-proven'
if($AllowSyntheticProbe){$ownershipProven=[bool]$SyntheticOwnershipProven;$ownershipDetail=if($ownershipProven){'synthetic-project-owner'}else{'synthetic-owner-unverified'}}
elseif($listening -and (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue)){
  $owners=@(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue|Select-Object -ExpandProperty OwningProcess -Unique)
  foreach($ownerPid in $owners){
    $process=Get-CimInstance Win32_Process -Filter "ProcessId=$ownerPid" -ErrorAction SilentlyContinue
    $commandLine=[string]$process.CommandLine
    if(!$commandLine){$commandLine=[string]$process.ExecutablePath}
    if($commandLine -and $commandLine.IndexOf($project,[StringComparison]::OrdinalIgnoreCase) -ge 0){$ownershipProven=$true;$ownershipDetail="project-owned pid $ownerPid";break}
  }
}
$healthChecked=$false;$healthPassed=$false;$healthDetail='not-requested'
if($ProbeState -eq 'ListeningHealthy'){$healthChecked=$true;$healthPassed=$true;$healthDetail='synthetic-healthy'}
elseif($ProbeState -eq 'ListeningUnhealthy'){$healthChecked=$true;$healthPassed=$false;$healthDetail='synthetic-unhealthy'}
elseif($listening -and ![string]::IsNullOrWhiteSpace($HealthUri)){
  $healthChecked=$true
  try{
    $response=Invoke-WebRequest -Uri $HealthUri -UseBasicParsing -TimeoutSec 3
    $status=[int]$response.StatusCode
    $contentMatches=[string]::IsNullOrWhiteSpace($ExpectedContent) -or ([string]$response.Content -match [regex]::Escape($ExpectedContent))
    $healthPassed=$status -ge 200 -and $status -lt 400 -and $contentMatches
    $healthDetail="HTTP $status; contentMatch=$contentMatches"
  }catch{$healthDetail="health probe failed: $($_.Exception.Message)"}
}

$status=if(!$listening){'START_ALLOWED'}elseif($healthPassed -and $ownershipProven){'REUSE_EXISTING'}elseif($healthChecked -and !$healthPassed){'EXISTING_UNHEALTHY'}else{'OCCUPIED_UNVERIFIED'}
$result=[ordered]@{
  schemaVersion=1;projectPath=$project;port=$Port;healthUri=$HealthUri;status=$status
  listening=$listening;healthChecked=$healthChecked;healthPassed=$healthPassed;healthDetail=$healthDetail
  ownershipProven=$ownershipProven;ownershipDetail=$ownershipDetail
  reuseExisting=($status -eq 'REUSE_EXISTING');startAllowed=($status -eq 'START_ALLOWED')
  requiredAction=switch($status){'REUSE_EXISTING'{'Reuse the current project service; do not start another process.'}'START_ALLOWED'{'No listener was found on the expected port; one scoped project service may be started.'}'EXISTING_UNHEALTHY'{'Diagnose or repair the existing listener; do not start a duplicate service or choose another port.'}default{'Identify and verify the existing listener; do not start a duplicate service or choose another port.'}}
}
if($Json){$result|ConvertTo-Json -Depth 4}else{[pscustomobject]$result|Format-List}
