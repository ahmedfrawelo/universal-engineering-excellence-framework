[CmdletBinding()]
param(
  [string]$Endpoint = '',
  [string]$PolicyPath = '',
  [string]$VersionJsonPath = '',
  [string]$TargetsJsonPath = '',
  [string]$ExpectedTargetId = '',
  [string[]]$PriorStageFailure = @(),
  [switch]$AuthorizedLastResort,
  [switch]$Json
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if([string]::IsNullOrWhiteSpace($PolicyPath)){$PolicyPath=Join-Path $root 'config\browser-emergency-fallback.json'}
$policy=Get-Content -LiteralPath $PolicyPath -Raw|ConvertFrom-Json
if($policy.schemaVersion -ne 1){throw 'Unsupported browser emergency fallback policy schema.'}
if(!$policy.enabled -or $policy.mode -ne 'explicit-last-resort' -or !$policy.requiresExplicitUserAuthorization -or !$policy.existingBrowserOnly -or !$policy.sameTargetRequired){throw 'Browser emergency fallback policy is not fail-closed.'}
if([string]::IsNullOrWhiteSpace($Endpoint)){$Endpoint=[string]$policy.defaultEndpoint}
$uri=[uri]$Endpoint
$loopbackHosts=@('127.0.0.1','localhost','::1')
if($uri.Scheme -ne 'http' -or $uri.Host -notin $loopbackHosts -or $uri.Host -notin @($policy.allowedHosts)){throw 'Remote debugging readiness accepts loopback HTTP endpoints only.'}
if(!$AuthorizedLastResort){
  $result=[pscustomobject]@{schemaVersion=1;status='NOT_AUTHORIZED';endpoint=$Endpoint;existingBrowser=$false;targets=0;reason='Explicit last-resort authorization is required after prior stages fail.'}
  if($Json){$result|ConvertTo-Json -Depth 5}else{$result|Format-List}; exit 0
}
$recordedFailures=@($PriorStageFailure|ForEach-Object{$_ -split ','}|Where-Object{$_})
$missingStages=@($policy.requiredPriorStages|Where-Object{$_ -notin $recordedFailures})
if($missingStages.Count){
  $result=[pscustomobject]@{schemaVersion=1;status='PRIOR_STAGES_INCOMPLETE';endpoint=$Endpoint;existingBrowser=$false;targets=0;missingStages=$missingStages;reason='Every configured prior control stage must have recorded failure evidence.'}
  if($Json){$result|ConvertTo-Json -Depth 5}else{$result|Format-List}; exit 0
}
if([string]::IsNullOrWhiteSpace($ExpectedTargetId)){throw 'Remote debugging readiness requires the exact existing dedicated target id.'}
if($VersionJsonPath){$version=Get-Content -LiteralPath $VersionJsonPath -Raw|ConvertFrom-Json}else{$version=Invoke-RestMethod -Uri ($Endpoint.TrimEnd('/')+'/json/version') -Method Get -TimeoutSec 3}
if($TargetsJsonPath){$targets=@(Get-Content -LiteralPath $TargetsJsonPath -Raw|ConvertFrom-Json)}else{$targets=@(Invoke-RestMethod -Uri ($Endpoint.TrimEnd('/')+'/json/list') -Method Get -TimeoutSec 3)}
$browserSocket=[string]$version.webSocketDebuggerUrl
if([string]::IsNullOrWhiteSpace($browserSocket)){throw 'Remote debugging endpoint did not expose an existing browser socket.'}
$socketUri=[uri]$browserSocket
if($socketUri.Scheme -notin @('ws','wss') -or $socketUri.Host -notin $loopbackHosts -or $socketUri.Host -notin @($policy.allowedHosts)){throw 'Remote debugging browser socket is not a loopback WebSocket.'}
$pageTargets=@($targets|Where-Object {$_.type -eq 'page' -and [string]$_.id -eq $ExpectedTargetId -and ![string]::IsNullOrWhiteSpace([string]$_.webSocketDebuggerUrl)})
if($pageTargets.Count -ne 1){throw 'The exact existing dedicated target was not uniquely identified.'}
$targetSocket=[uri][string]$pageTargets[0].webSocketDebuggerUrl
if($targetSocket.Scheme -notin @('ws','wss') -or $targetSocket.Host -notin $loopbackHosts -or $targetSocket.Host -notin @($policy.allowedHosts)){throw 'Remote debugging target socket is not a loopback WebSocket.'}
$status='READY_LAST_RESORT'
$result=[pscustomobject]@{schemaVersion=1;status=$status;endpoint=$Endpoint;existingBrowser=$true;sameTargetProven=$true;targetId=$ExpectedTargetId;targets=$pageTargets.Count;browser=[string]$version.Browser;restrictions=@($policy.forbidden);requiredPriorStages=@($policy.requiredPriorStages)}
if($Json){$result|ConvertTo-Json -Depth 6}else{$result|Format-List}
