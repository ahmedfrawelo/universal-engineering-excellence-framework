$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$pack = Join-Path $root 'framework/20-repository-evolution/02-performance-forensics'
$required = @(
  'README.md',
  '00-performance-forensics-system.md',
  '01-scope-and-flow-tracing.md',
  '02-measurement-and-benchmarking.md',
  '03-checklist-domains.md',
  '04-version-runtime-and-hidden-work.md',
  '05-correctness-cost-and-approval.md',
  '06-report-template.md',
  '07-approved-implementation-and-regression.md',
  'INDEX.md'
)
foreach ($file in $required) {
  $path = Join-Path $pack $file
  if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing performance forensics file: $file" }
}
$system = Get-Content -LiteralPath (Join-Path $pack '00-performance-forensics-system.md') -Raw
$template = Get-Content -LiteralPath (Join-Path $pack '06-report-template.md') -Raw
$loader = Get-Content -LiteralPath (Join-Path $root 'framework/01-core/01-master-loader.md') -Raw
foreach ($term in @('Audit mode is report-only','Every recommendation must cite','Stop for explicit approval')) {
  if ($system -notmatch [regex]::Escape($term)) { throw "Performance forensics system missing term: $term" }
}
foreach ($term in @('Complete checklist results','Approval gate','Additional techniques discovered','Completeness statement')) {
  if ($template -notmatch [regex]::Escape($term)) { throw "Performance report template missing section: $term" }
}
if ($loader -notmatch 'framework/20-repository-evolution/02-performance-forensics/') { throw 'Master loader does not route performance forensics tasks.' }
Write-Host 'Performance forensics tests passed'
