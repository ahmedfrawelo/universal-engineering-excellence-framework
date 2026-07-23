[CmdletBinding()]
param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [ValidateSet('Quick','Full')][string]$Mode = 'Quick',
  [string]$SummaryPath,
  [string]$ReportPath,
  [switch]$Enforce
)

$ErrorActionPreference = 'Stop'
$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$budgetPath = Join-Path $resolvedRoot 'config\assurance-budgets.json'
if (!(Test-Path -LiteralPath $budgetPath -PathType Leaf)) { throw "Missing assurance budget file: $budgetPath" }
$budgets = Get-Content -LiteralPath $budgetPath -Raw | ConvertFrom-Json
if ($budgets.schemaVersion -ne 1) { throw "Unsupported assurance budget schema: $($budgets.schemaVersion)" }
$budget = if ($Mode -eq 'Quick') { $budgets.quick } else { $budgets.full }

if ($SummaryPath) {
  $summary = Get-Content -LiteralPath $SummaryPath -Raw | ConvertFrom-Json
} else {
  $audit = Join-Path $resolvedRoot 'scripts\ueef-audit.ps1'
  $watch = [Diagnostics.Stopwatch]::StartNew()
  $auditOutput = if ($Mode -eq 'Quick') { & $audit -Root $resolvedRoot -Quick -Json } else { & $audit -Root $resolvedRoot -Json }
  $auditExit = $LASTEXITCODE
  $watch.Stop()
  if ($auditExit -ne 0) { throw "UEEF audit failed with exit code $auditExit; performance measurement is not a substitute for correctness." }
  $summary = $auditOutput | ConvertFrom-Json
  $summary | Add-Member -NotePropertyName wallClockMs -NotePropertyValue ([int]$watch.ElapsedMilliseconds) -Force
}

if (!$summary.checks) { throw 'Assurance summary has no checks.' }
$violations = [Collections.Generic.List[string]]::new()
$auditPassed = ([string]$summary.status -eq 'PASS')
if (!$auditPassed) { $violations.Add("Audit status is $($summary.status), not PASS") }
$totalMs = [int64]0
foreach ($check in @($summary.checks)) {
  if ($null -eq $check.durationMs -or [int64]$check.durationMs -lt 0) { $violations.Add("Invalid duration for check: $($check.name)"); continue }
  $totalMs += [int64]$check.durationMs
  $limit = $budget.checks.($check.name)
  if ($null -ne $limit -and [int64]$check.durationMs -gt [int64]$limit) { $violations.Add("$($check.name) exceeded $limit ms: $($check.durationMs) ms") }
}
if ($totalMs -gt [int64]$budget.totalMaxMs) { $violations.Add("$Mode assurance exceeded $($budget.totalMaxMs) ms: $totalMs ms") }
$result = [ordered]@{
  schemaVersion = 1
  mode = $Mode
  auditStatus = [string]$summary.status
  totalDurationMs = $totalMs
  wallClockMs = if ($summary.wallClockMs) { [int64]$summary.wallClockMs } else { $null }
  budgetTotalMs = [int64]$budget.totalMaxMs
  withinBudget = ($violations.Count -eq 0)
  violations = @($violations)
}
if ($ReportPath) { $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath -Encoding utf8 }
$result | ConvertTo-Json -Depth 5
if ($Enforce -and !$result.withinBudget) { exit 1 }
exit 0
