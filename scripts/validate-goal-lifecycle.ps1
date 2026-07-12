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
  [switch]$VerificationRecorded
)
$ErrorActionPreference = 'Stop'

$blockedAllowed = $GoalStatus -eq 'BLOCKED' -and $BlockerExternalOrUserOnly -and $NoMeaningfulLocalWorkRemaining -and $ExternalStateChangeRequired
$completeAllowed = $GoalStatus -eq 'COMPLETE' -and $RequestedOutcomeSatisfied -and !$RequiredWorkRemaining -and $GatesPassOrAccepted -and $VerificationRecorded
$terminalAllowed = $StatusOnly -or $completeAllowed -or $blockedAllowed

if ($GoalStatus -eq 'BLOCKED' -and !$blockedAllowed) { throw 'Invalid BLOCKED transition.' }
if ($GoalStatus -eq 'COMPLETE' -and !$completeAllowed) { throw 'Invalid COMPLETE transition.' }
if ($TerminalFinal -and !$terminalAllowed) { throw 'Terminal final response is forbidden for this goal state.' }

[pscustomobject]@{ GoalStatus=$GoalStatus; TerminalFinalAllowed=$terminalAllowed; BlockedAllowed=$blockedAllowed; CompleteAllowed=$completeAllowed }
