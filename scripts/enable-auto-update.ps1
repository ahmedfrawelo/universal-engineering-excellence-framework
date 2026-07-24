param(
  [Parameter(Mandatory)][string]$CodexHome,
  [string]$Agent = 'codex',
  [int]$IntervalMinutes = 15,
  [switch]$SkipImmediateRun
)
$ErrorActionPreference = 'Stop'
if ($IntervalMinutes -lt 15 -or $IntervalMinutes -gt 1440) { throw 'IntervalMinutes must be between 15 and 1440.' }
if ($Agent -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$') { throw 'Unsafe agent name.' }
$resolvedCodexHome = (Resolve-Path -LiteralPath $CodexHome).Path
$runtime = Join-Path $resolvedCodexHome "ueef\$Agent"
$worker = Join-Path $runtime 'scripts\auto-update.ps1'
if (!(Test-Path -LiteralPath $worker)) { throw "Auto-update worker is missing: $worker" }
$launcher = Join-Path $runtime 'scripts\run-auto-update.vbs'
if (!(Test-Path -LiteralPath $launcher)) { throw "Auto-update launcher is missing: $launcher" }
$name = "UEEF-$Agent-AutoUpdate"
$taskAction = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$launcher`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -RepetitionDuration (New-TimeSpan -Days 9999)
Register-ScheduledTask -TaskName $name -Action $taskAction -Trigger $trigger -Description 'Keeps the UEEF Codex runtime synchronized with origin/main.' -Force | Out-Null
if (!$SkipImmediateRun) { Start-ScheduledTask -TaskName $name }
Write-Host "UEEF automatic updates enabled every $IntervalMinutes minutes: $name"
