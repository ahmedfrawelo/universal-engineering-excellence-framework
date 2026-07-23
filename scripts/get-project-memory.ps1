[CmdletBinding()]
param(
  [string]$Root=(Get-Location).Path,
  [switch]$IncludeExpired,
  [string]$Query,
  [switch]$Summary,
  [switch]$Json
)
$ErrorActionPreference='Stop'
$memoryRoot=Join-Path $Root '.ueef\memory';$now=(Get-Date).ToUniversalTime();$items=@()
if(Test-Path -LiteralPath $memoryRoot){$items=@(Get-ChildItem -LiteralPath $memoryRoot -Filter '*.json' -File|ForEach-Object{Get-Content $_.FullName -Raw|ConvertFrom-Json}|Where-Object{$IncludeExpired -or [datetime]$_.expiresAt -gt $now})}
if($Query){$escaped=[regex]::Escape($Query);$items=@($items|Where-Object{"$($_.title) $($_.detail) $($_.kind)" -match $escaped})}
$items=@($items|Sort-Object createdAt -Descending)
if($Summary){$result=[ordered]@{schemaVersion=1;query=$Query;activeRecords=$items.Count;decisionTitles=@($items|Where-Object kind -eq 'decision'|Select-Object -First 10 -ExpandProperty title);records=@($items);policyPromotion='human-approval-required';automaticPolicyChange=$false};if($Json){$result|ConvertTo-Json -Depth 5}else{$result|Format-List}}elseif($Json){if($items.Count -eq 0){Write-Output '[]'}else{ConvertTo-Json -InputObject @($items) -Depth 4}}else{$items|Select-Object kind,title,createdAt,expiresAt|Format-Table -AutoSize}
