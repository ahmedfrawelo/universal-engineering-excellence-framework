param(
  [Parameter(Mandatory)][string]$CodexHome,
  [string]$Agent = 'codex',
  [int]$IntervalMinutes = 15,
  [switch]$SkipImmediateRun
)
$ErrorActionPreference = 'Stop'
if ($IntervalMinutes -lt 15 -or $IntervalMinutes -gt 1440) { throw 'IntervalMinutes must be between 15 and 1440.' }
if ($Agent -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$') { throw 'Unsafe agent name.' }
$home = (Resolve-Path -LiteralPath $CodexHome).Path
$runtime = Join-Path $home "ueef\$Agent"
$worker = Join-Path $runtime 'scripts\auto-update.ps1'
if (!(Test-Path -LiteralPath $worker)) { throw "Auto-update worker is missing: $worker" }
$name = "UEEF-$Agent-AutoUpdate"
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$worker`""
$trigger = New-ScheduledTaskTrigger -Daily -At 00:00 -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -RepetitionDuration (New-TimeSpan -Days 1)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Settings $settings -Description 'Keeps the UEEF Codex runtime synchronized with origin/main.' -Force | Out-Null
if (!$SkipImmediateRun) { Start-ScheduledTask -TaskName $name }
Write-Host "UEEF automatic updates enabled every $IntervalMinutes minutes: $name"
