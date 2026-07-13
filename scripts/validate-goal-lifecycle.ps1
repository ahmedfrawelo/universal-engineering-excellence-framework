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
  [switch]$VisualVerificationPassed
)
$ErrorActionPreference = 'Stop'

$blockedAllowed = $GoalStatus -eq 'BLOCKED' -and $BlockerExternalOrUserOnly -and $NoMeaningfulLocalWorkRemaining -and $ExternalStateChangeRequired
$browserAllowed = !$BrowserVerificationRequired -or $BrowserVerificationPassed
$visualAllowed = !$VisualVerificationRequired -or $VisualVerificationPassed
$completeAllowed = $GoalStatus -eq 'COMPLETE' -and $RequestedOutcomeSatisfied -and !$RequiredWorkRemaining -and $GatesPassOrAccepted -and $VerificationRecorded -and $browserAllowed -and $visualAllowed
$terminalAllowed = $StatusOnly -or $completeAllowed -or $blockedAllowed

if ($GoalStatus -eq 'BLOCKED' -and !$blockedAllowed) { throw 'Invalid BLOCKED transition.' }
if ($GoalStatus -eq 'COMPLETE' -and !$completeAllowed) { throw 'Invalid COMPLETE transition.' }
if ($TerminalFinal -and !$terminalAllowed) { throw 'Terminal final response is forbidden for this goal state.' }

[pscustomobject]@{ GoalStatus=$GoalStatus; TerminalFinalAllowed=$terminalAllowed; BlockedAllowed=$blockedAllowed; CompleteAllowed=$completeAllowed; BrowserVerificationAllowed=$browserAllowed; VisualVerificationAllowed=$visualAllowed }
