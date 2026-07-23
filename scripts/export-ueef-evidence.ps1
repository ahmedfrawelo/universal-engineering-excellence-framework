[CmdletBinding()]
param([string]$RepositoryPath=(Get-Location).Path,[string]$OutputPath,[switch]$IncludeDiff,[switch]$IncludeMemorySummary,[string]$Task,[switch]$Preview)
$ErrorActionPreference='Stop';if(!$Preview -and !$OutputPath){throw 'OutputPath is required unless -Preview is used.'};$scriptRoot=$PSScriptRoot
$status=(& (Join-Path $scriptRoot 'ueef-status.ps1') -RepositoryPath $RepositoryPath -SkipRuntimeDrift -Json|Out-String)|ConvertFrom-Json
$health=$null;try{$health=(& (Join-Path $scriptRoot 'get-ueef-health.ps1') -RepositoryPath $RepositoryPath -Json|Out-String)|ConvertFrom-Json}catch{}
$diff=$null;if($IncludeDiff){$diff=(& (Join-Path $scriptRoot 'get-diff-impact.ps1') -RepositoryPath $RepositoryPath -Json|Out-String)|ConvertFrom-Json}
$memory=$null;if($IncludeMemorySummary){$memory=(& (Join-Path $scriptRoot 'get-project-memory.ps1') -Root $RepositoryPath -Summary -Json|Out-String)|ConvertFrom-Json}
$preflight=$null;if($Task){$preflight=(& (Join-Path $scriptRoot 'get-ueef-task-preflight.ps1') -Task $Task -Json|Out-String)|ConvertFrom-Json}
$redact={param($text)[regex]::Replace($text,'(?i)(password|token|secret|api[_-]?key)\s*[:=]\s*[^\s,;]+','$1=[REDACTED]')}
$report=[ordered]@{schemaVersion=2;generatedAt=(Get-Date).ToUniversalTime().ToString('o');provenance=[ordered]@{repositoryPath=$RepositoryPath;runtimeVersion=$status.version};runtime=$status;health=$health;diff=$diff;memorySummary=$memory;preflight=$preflight;redaction='credential-like values are redacted';preview=$Preview.IsPresent};$json=&$redact ($report|ConvertTo-Json -Depth 14)
if($Preview){Write-Output $json;return};New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force|Out-Null;Set-Content -LiteralPath $OutputPath -Value $json -Encoding utf8;Write-Output "Evidence exported: $OutputPath"
