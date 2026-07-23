[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('decision','rejected-option','owner','lesson')][string]$Kind,
  [Parameter(Mandatory)][ValidateLength(1,400)][string]$Title,
  [Parameter(Mandatory)][ValidateLength(1,4000)][string]$Detail,
  [ValidateLength(1,200)][string]$Task,
  [string]$Root = (Get-Location).Path,
  [ValidateRange(1,3650)][int]$RetentionDays = 180,
  [switch]$Json
)
$ErrorActionPreference='Stop'
if($Detail -match '(?i)(password|api[_ -]?key|secret|token\s*=|private key)'){throw 'Project memory must not contain credentials or secrets.'}
$memoryRoot=Join-Path $Root '.ueef\memory'; New-Item -ItemType Directory -Path $memoryRoot -Force|Out-Null
$record=[ordered]@{schemaVersion=1;id=[guid]::NewGuid().ToString('N');kind=$Kind;title=$Title;detail=$Detail;task=$Task;createdAt=(Get-Date).ToUniversalTime().ToString('o');expiresAt=(Get-Date).ToUniversalTime().AddDays($RetentionDays).ToString('o');source='explicit-user-or-agent-record';automaticPolicyChange=$false}
$path=Join-Path $memoryRoot "$($record.createdAt.Substring(0,10))-$($record.id).json"; $record|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $path -Encoding utf8
if($Json){$record|ConvertTo-Json -Depth 4}else{Write-Output "Project memory recorded: $($record.id)"}
