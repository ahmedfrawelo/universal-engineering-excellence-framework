[CmdletBinding()]
param(
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# Only reset the Codex Chrome native-messaging host after an exact stale-tab claim conflict.
$targets = Get-CimInstance Win32_Process -Filter "Name='extension-host.exe'" | Where-Object {
  $_.CommandLine -match 'chrome-extension://hehggadaopoacecdllhhajmbjkdcmajg/' -and
  $_.CommandLine -match '[\\/]plugins[\\/]cache[\\/]openai-bundled[\\/]chrome[\\/]'
}

if (!$targets) {
  [pscustomobject]@{ Status = 'NoExtensionHostFound'; Repaired = $false; ProcessIds = @() }
  return
}

$processIds = @($targets | ForEach-Object { [int]$_.ProcessId })
if ($DryRun) {
  [pscustomobject]@{ Status = 'DryRun'; Repaired = $false; ProcessIds = $processIds }
  return
}

foreach ($processId in $processIds) {
  Stop-Process -Id $processId -Force -ErrorAction Stop
}

Start-Sleep -Milliseconds 500
[pscustomobject]@{
  Status = 'ExtensionHostReset'
  Repaired = $true
  ProcessIds = $processIds
  NextStep = 'Reset the task Node REPL, bootstrap the same Chrome extension, enumerate user.openTabs(), and claim the exact tab once.'
}
