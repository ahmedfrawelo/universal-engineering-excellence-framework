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
  [string]$UserFacingStatus
)
$ErrorActionPreference = 'Stop'

$blockedAllowed = $GoalStatus -eq 'BLOCKED' -and $BlockerExternalOrUserOnly -and $NoMeaningfulLocalWorkRemaining -and $ExternalStateChangeRequired
$handoffAllowed = $VerifiedBrowserEvidenceHandoff -and $HandoffMatchesCurrentCodeState
$browserAllowed = !$BrowserVerificationRequired -or $BrowserVerificationPassed -or $handoffAllowed
$visualAllowed = !$VisualVerificationRequired -or $VisualVerificationPassed -or $handoffAllowed
$completeAllowed = $GoalStatus -eq 'COMPLETE' -and $RequestedOutcomeSatisfied -and !$RequiredWorkRemaining -and $GatesPassOrAccepted -and $VerificationRecorded -and $browserAllowed -and $visualAllowed
$terminalAllowed = $StatusOnly -or $completeAllowed -or $blockedAllowed

if ($GoalStatus -eq 'BLOCKED' -and !$blockedAllowed) { throw 'Invalid BLOCKED transition.' }
if ($GoalStatus -eq 'BLOCKED' -and $ThreadControlChannelDegraded -and !$ChromeExternallyUnavailable) { throw 'Thread-local browser control degradation is not a valid BLOCKED transition.' }
if ($UserRestartChromeRequested -and !$ChromeExternallyUnavailable) { throw 'A Chrome restart request requires independent Chrome unavailability evidence.' }
if ($ThreadControlChannelDegraded -and !$ChromeExternallyUnavailable -and $UserFacingStatus -and $UserFacingStatus -ne 'Browser verification is being completed on your existing tab; implementation continues.') { throw 'Thread-local browser degradation requires the canonical user-facing recovery status.' }
if (($BrowserVerificationRequired -or $VisualVerificationRequired) -and $VerifiedBrowserEvidenceHandoff -and !$HandoffMatchesCurrentCodeState) { throw 'Browser evidence handoff does not cover the current code state.' }
if ($GoalStatus -eq 'COMPLETE' -and !$completeAllowed) { throw 'Invalid COMPLETE transition.' }
if ($TerminalFinal -and !$terminalAllowed) { throw 'Terminal final response is forbidden for this goal state.' }

[pscustomobject]@{ GoalStatus=$GoalStatus; TerminalFinalAllowed=$terminalAllowed; BlockedAllowed=$blockedAllowed; CompleteAllowed=$completeAllowed; BrowserVerificationAllowed=$browserAllowed; VisualVerificationAllowed=$visualAllowed; EvidenceHandoffAllowed=$handoffAllowed }
