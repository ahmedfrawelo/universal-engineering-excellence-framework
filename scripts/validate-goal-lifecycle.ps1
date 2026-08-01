param(
  [ValidateSet('ACTIVE','BLOCKED','COMPLETE')][string]$GoalStatus,
  [switch]$TerminalFinal,
  [switch]$StatusOnly,
  [switch]$BlockerExternalOrUserOnly,
  [switch]$NoMeaningfulLocalWorkRemaining,
  [switch]$ExternalStateChangeRequired,
  [switch]$RequestedOutcomeSatisfied,
  [switch]$RequiredWorkRemaining,
  [switch]$GatesPassOrAccepted,
  [switch]$VerificationRecorded,
  [switch]$BrowserVerificationRequired,
  [switch]$BrowserVerificationPassed,
  [switch]$VisualVerificationRequired,
  [switch]$VisualVerificationPassed,
  [switch]$ThreadControlChannelDegraded,
  [switch]$VerifiedBrowserEvidenceHandoff,
  [switch]$HandoffMatchesCurrentCodeState,
  [switch]$ChromeExternallyUnavailable,
  [switch]$UserRestartChromeRequested,
  [switch]$PendingScreenshotEvidence,
  [int]$ProgressPercent = -1,
  [switch]$ProgressUpdate,
  [switch]$ProgressHasNewEvidence,
  [switch]$ProgressHasCurrentAction,
  [switch]$ProgressHasNextGate,
  [string]$CompletionAuditPath = '',
  [ValidateSet('discovery','planning','implementation','validation','release','complete','unknown')][string]$ProgressPhase = 'unknown',
  [string]$UserFacingStatus
)
$ErrorActionPreference = 'Stop'

$completionAuditPassed = $false
if ($GoalStatus -eq 'COMPLETE' -and ![string]::IsNullOrWhiteSpace($CompletionAuditPath)) {
  & (Join-Path $PSScriptRoot 'validate-completion-audit.ps1') -Path $CompletionAuditPath | Out-Null
  $completionAuditPassed = $true
}

$blockedAllowed = $GoalStatus -eq 'BLOCKED' -and $BlockerExternalOrUserOnly -and $NoMeaningfulLocalWorkRemaining -and $ExternalStateChangeRequired
$handoffAllowed = $VerifiedBrowserEvidenceHandoff -and $HandoffMatchesCurrentCodeState
$browserAllowed = !$BrowserVerificationRequired -or $BrowserVerificationPassed -or $handoffAllowed
$visualAllowed = !$VisualVerificationRequired -or $VisualVerificationPassed -or $handoffAllowed
$completeAllowed = $GoalStatus -eq 'COMPLETE' -and $RequestedOutcomeSatisfied -and !$RequiredWorkRemaining -and $GatesPassOrAccepted -and $VerificationRecorded -and $completionAuditPassed -and $browserAllowed -and $visualAllowed
$terminalAllowed = $StatusOnly -or $completeAllowed -or $blockedAllowed

if ($GoalStatus -eq 'BLOCKED' -and !$blockedAllowed) { throw 'Invalid BLOCKED transition.' }
if ($GoalStatus -eq 'BLOCKED' -and $BrowserVerificationRequired -and !$ChromeExternallyUnavailable) { throw 'Browser verification requirement is not a valid BLOCKED transition without independent Chrome unavailability evidence.' }
if ($GoalStatus -eq 'BLOCKED' -and $ThreadControlChannelDegraded -and !$ChromeExternallyUnavailable) { throw 'Thread-local browser control degradation is not a valid BLOCKED transition.' }
if ($GoalStatus -eq 'BLOCKED' -and $PendingScreenshotEvidence) { throw 'Pending screenshot evidence is not a valid BLOCKED transition.' }
if ($UserRestartChromeRequested -and !$ChromeExternallyUnavailable) { throw 'A Chrome restart request requires independent Chrome unavailability evidence.' }
if ($ThreadControlChannelDegraded -and !$ChromeExternallyUnavailable -and $UserFacingStatus -and $UserFacingStatus -ne 'Browser verification is being completed on your existing tab; implementation continues.') { throw 'Thread-local browser degradation requires the canonical user-facing recovery status.' }
if (($BrowserVerificationRequired -or $VisualVerificationRequired) -and $VerifiedBrowserEvidenceHandoff -and !$HandoffMatchesCurrentCodeState) { throw 'Browser evidence handoff does not cover the current code state.' }
if ($ProgressPercent -gt 100) { throw 'Progress percent cannot exceed 100.' }
if ($ProgressUpdate -and $ProgressPercent -lt 0) { throw 'Progress updates require an explicit conservative percentage.' }
if ($ProgressUpdate -and $ProgressPhase -eq 'unknown') { throw 'Progress updates require an explicit phase.' }
if ($ProgressPercent -eq 100 -and $GoalStatus -ne 'COMPLETE') { throw 'Progress cannot be 100 before the goal is complete.' }
if ($ProgressPhase -in @('discovery','planning') -and $ProgressPercent -gt 30) { throw 'Discovery or planning progress cannot exceed 30 percent.' }
if ($ProgressPhase -eq 'implementation' -and $ProgressPercent -gt 75) { throw 'Implementation progress cannot exceed 75 percent before validation.' }
if ($ProgressPhase -in @('validation','release') -and $ProgressPercent -gt 95 -and $GoalStatus -ne 'COMPLETE') { throw 'Validation or release progress cannot exceed 95 percent before completion.' }
if ($ProgressUpdate -and (!$ProgressHasNewEvidence -or !$ProgressHasCurrentAction -or !$ProgressHasNextGate)) { throw 'Progress updates require new evidence, current action, and next gate.' }
if ($GoalStatus -eq 'COMPLETE' -and !$completeAllowed) { throw 'Invalid COMPLETE transition.' }
if ($TerminalFinal -and !$terminalAllowed) { throw 'Terminal final response is forbidden for this goal state.' }

[pscustomobject]@{ GoalStatus=$GoalStatus; TerminalFinalAllowed=$terminalAllowed; BlockedAllowed=$blockedAllowed; CompleteAllowed=$completeAllowed; CompletionAuditPassed=$completionAuditPassed; BrowserVerificationAllowed=$browserAllowed; VisualVerificationAllowed=$visualAllowed; EvidenceHandoffAllowed=$handoffAllowed; ProgressPercent=$ProgressPercent; ProgressPhase=$ProgressPhase; ProgressUpdate=$ProgressUpdate.IsPresent }
