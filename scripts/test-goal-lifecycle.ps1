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
Assert-Rejected @{GoalStatus='COMPLETE';TerminalFinal=$true;RequestedOutcomeSatisfied=$true;GatesPassOrAccepted=$true;VerificationRecorded=$true;BrowserVerificationRequired=$true}
Assert-Rejected @{GoalStatus='COMPLETE';TerminalFinal=$true;RequestedOutcomeSatisfied=$true;GatesPassOrAccepted=$true;VerificationRecorded=$true;VisualVerificationRequired=$true}
Assert-Rejected @{GoalStatus='COMPLETE';TerminalFinal=$true;RequestedOutcomeSatisfied=$true;GatesPassOrAccepted=$true;VerificationRecorded=$true;BrowserVerificationRequired=$true;VisualVerificationRequired=$true}
Assert-Rejected @{GoalStatus='BLOCKED';TerminalFinal=$true;BlockerExternalOrUserOnly=$true;NoMeaningfulLocalWorkRemaining=$true;ExternalStateChangeRequired=$true;ThreadControlChannelDegraded=$true}
Assert-Rejected @{GoalStatus='BLOCKED';TerminalFinal=$true;BlockerExternalOrUserOnly=$true;NoMeaningfulLocalWorkRemaining=$true;ExternalStateChangeRequired=$true;BrowserVerificationRequired=$true}
Assert-Rejected @{GoalStatus='ACTIVE';BrowserVerificationRequired=$true;VerifiedBrowserEvidenceHandoff=$true}
Assert-Rejected @{GoalStatus='ACTIVE';UserRestartChromeRequested=$true}
Assert-Rejected @{GoalStatus='ACTIVE';ThreadControlChannelDegraded=$true;UserFacingStatus='Browser bridge failed three times.'}
Assert-Rejected @{GoalStatus='ACTIVE';ThreadControlChannelDegraded=$true;UserFacingStatus='Stopped visual verification.'}
Assert-Rejected @{GoalStatus='BLOCKED';TerminalFinal=$true;BlockerExternalOrUserOnly=$true;NoMeaningfulLocalWorkRemaining=$true;ExternalStateChangeRequired=$true;PendingScreenshotEvidence=$true}
Assert-Rejected @{GoalStatus='ACTIVE';ProgressUpdate=$true;ProgressPercent=40;ProgressPhase='planning';ProgressHasCurrentAction=$true;ProgressHasNextGate=$true;ProgressHasNewEvidence=$true}
Assert-Rejected @{GoalStatus='ACTIVE';ProgressUpdate=$true;ProgressPercent=80;ProgressPhase='implementation';ProgressHasCurrentAction=$true;ProgressHasNextGate=$true;ProgressHasNewEvidence=$true}
Assert-Rejected @{GoalStatus='ACTIVE';ProgressUpdate=$true;ProgressPercent=100;ProgressPhase='validation';ProgressHasCurrentAction=$true;ProgressHasNextGate=$true;ProgressHasNewEvidence=$true}
Assert-Rejected @{GoalStatus='ACTIVE';ProgressUpdate=$true;ProgressPercent=50;ProgressPhase='implementation';ProgressHasCurrentAction=$true;ProgressHasNextGate=$true}
Assert-Rejected @{GoalStatus='ACTIVE';ProgressUpdate=$true;ProgressPhase='implementation';ProgressHasCurrentAction=$true;ProgressHasNextGate=$true;ProgressHasNewEvidence=$true}
Assert-Rejected @{GoalStatus='ACTIVE';ProgressUpdate=$true;ProgressPercent=50;ProgressHasCurrentAction=$true;ProgressHasNextGate=$true;ProgressHasNewEvidence=$true}
& $validator -GoalStatus ACTIVE | Out-Null
& $validator -GoalStatus ACTIVE -TerminalFinal -StatusOnly | Out-Null
& $validator -GoalStatus ACTIVE -ProgressUpdate -ProgressPercent 25 -ProgressPhase planning -ProgressHasNewEvidence -ProgressHasCurrentAction -ProgressHasNextGate | Out-Null
& $validator -GoalStatus ACTIVE -ProgressUpdate -ProgressPercent 75 -ProgressPhase implementation -ProgressHasNewEvidence -ProgressHasCurrentAction -ProgressHasNextGate | Out-Null
& $validator -GoalStatus ACTIVE -ProgressUpdate -ProgressPercent 95 -ProgressPhase validation -ProgressHasNewEvidence -ProgressHasCurrentAction -ProgressHasNextGate | Out-Null
& $validator -GoalStatus COMPLETE -TerminalFinal -RequestedOutcomeSatisfied -GatesPassOrAccepted -VerificationRecorded | Out-Null
& $validator -GoalStatus COMPLETE -TerminalFinal -RequestedOutcomeSatisfied -GatesPassOrAccepted -VerificationRecorded -ProgressPercent 100 -ProgressPhase complete | Out-Null
& $validator -GoalStatus COMPLETE -TerminalFinal -RequestedOutcomeSatisfied -GatesPassOrAccepted -VerificationRecorded -BrowserVerificationRequired -BrowserVerificationPassed -VisualVerificationRequired -VisualVerificationPassed | Out-Null
& $validator -GoalStatus COMPLETE -TerminalFinal -RequestedOutcomeSatisfied -GatesPassOrAccepted -VerificationRecorded -BrowserVerificationRequired -VisualVerificationRequired -VerifiedBrowserEvidenceHandoff -HandoffMatchesCurrentCodeState -ThreadControlChannelDegraded | Out-Null
& $validator -GoalStatus ACTIVE -ThreadControlChannelDegraded -UserFacingStatus 'Browser verification is being completed on your existing tab; implementation continues.' | Out-Null
$pendingVisual = & $validator -GoalStatus ACTIVE -PendingScreenshotEvidence
if ($pendingVisual.GoalStatus -ne 'ACTIVE' -or $pendingVisual.BlockedAllowed) {
  throw 'Pending browser evidence must keep nonvisual implementation active instead of blocked.'
}
& $validator -GoalStatus BLOCKED -TerminalFinal -BlockerExternalOrUserOnly -NoMeaningfulLocalWorkRemaining -ExternalStateChangeRequired | Out-Null
& $validator -GoalStatus BLOCKED -TerminalFinal -BlockerExternalOrUserOnly -NoMeaningfulLocalWorkRemaining -ExternalStateChangeRequired -BrowserVerificationRequired -ChromeExternallyUnavailable | Out-Null
Write-Host 'Goal lifecycle tests passed'
