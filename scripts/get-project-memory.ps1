[CmdletBinding()]
param([string]$Root=(Get-Location).Path,[switch]$IncludeExpired,[switch]$Json)
$ErrorActionPreference='Stop';$memoryRoot=Join-Path $Root '.ueef\memory';$now=(Get-Date).ToUniversalTime();$items=@()
if(Test-Path -LiteralPath $memoryRoot){$items=@(Get-ChildItem -LiteralPath $memoryRoot -Filter '*.json' -File|ForEach-Object{Get-Content $_.FullName -Raw|ConvertFrom-Json}|Where-Object{$IncludeExpired -or [datetime]$_.expiresAt -gt $now})}
if($Json){@($items)|ConvertTo-Json -Depth 4}else{$items|Select-Object kind,title,createdAt,expiresAt|Format-Table -AutoSize}
