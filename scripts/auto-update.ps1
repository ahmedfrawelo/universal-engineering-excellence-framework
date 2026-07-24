param([string]$RuntimeRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
$runtime = (Resolve-Path -LiteralPath $RuntimeRoot).Path
$statePath = Join-Path (Split-Path -Parent $runtime) 'UEEF-ACTIVE.json'
$logDirectory = Join-Path (Split-Path -Parent $runtime) 'logs'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$logPath = Join-Path $logDirectory 'auto-update.log'
function Write-UpdateLog([string]$Message) { Add-Content -LiteralPath $logPath -Encoding utf8 -Value "$(Get-Date -Format o) $Message" }

$mutex = [Threading.Mutex]::new($false, 'Local\UEEF-Codex-AutoUpdate')
if (!$mutex.WaitOne(0)) { exit 0 }
try {
  if (!(Test-Path -LiteralPath $statePath)) { throw "Missing runtime state: $statePath" }
  $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
  $source = [string]$state.sourceRepositoryPath
  if ([string]::IsNullOrWhiteSpace($source) -or !(Test-Path -LiteralPath (Join-Path $source '.git'))) { throw "Recorded source repository is unavailable: $source" }
  git -C $source fetch origin main --quiet
  if ($LASTEXITCODE -ne 0) { throw 'Unable to fetch origin/main.' }
  $local = (git -C $source rev-parse HEAD).Trim()
  $remote = (git -C $source rev-parse origin/main).Trim()
  if ($local -eq $remote) { Write-UpdateLog 'Already current.'; exit 0 }
  & (Join-Path $source 'scripts\update.ps1') -Root $runtime
  if ($LASTEXITCODE -ne 0) { throw 'Runtime update failed.' }
  Write-UpdateLog "Updated $local to $remote."
} catch { Write-UpdateLog "Update skipped: $($_.Exception.Message)" } finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
