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
$name = "UEEF-$Agent-AutoUpdate"
$taskAction = "powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$worker`""
& schtasks.exe /Create /TN $name /TR $taskAction /SC MINUTE /MO $IntervalMinutes /F | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Unable to register the automatic update task.' }
if (!$SkipImmediateRun) { & schtasks.exe /Run /TN $name | Out-Null }
Write-Host "UEEF automatic updates enabled every $IntervalMinutes minutes: $name"
