$ErrorActionPreference = 'Stop'
$validator = Join-Path $PSScriptRoot 'validate-goal-lifecycle.ps1'
function Assert-Rejected([hashtable]$Arguments) {
  $rejected = $false
  try { & $validator @Arguments | Out-Null } catch { $rejected = $true }
  if (!$rejected) { throw "Lifecycle case was incorrectly accepted: $($Arguments | ConvertTo-Json -Compress)" }
}
Assert-Rejected @{GoalStatus='ACTIVE';TerminalFinal=$true}
Assert-Rejected @{GoalStatus='COMPLETE';TerminalFinal=$true;RequiredWorkRemaining=$true}
Assert-Rejected @{GoalStatus='BLOCKED';TerminalFinal=$true}
Assert-Rejected @{GoalStatus='BLOCKED';TerminalFinal=$true;BlockerExternalOrUserOnly=$true;ExternalStateChangeRequired=$true}
& $validator -GoalStatus ACTIVE | Out-Null
& $validator -GoalStatus ACTIVE -TerminalFinal -StatusOnly | Out-Null
& $validator -GoalStatus COMPLETE -TerminalFinal -RequestedOutcomeSatisfied -GatesPassOrAccepted -VerificationRecorded | Out-Null
& $validator -GoalStatus BLOCKED -TerminalFinal -BlockerExternalOrUserOnly -NoMeaningfulLocalWorkRemaining -ExternalStateChangeRequired | Out-Null
Write-Host 'Goal lifecycle tests passed'
