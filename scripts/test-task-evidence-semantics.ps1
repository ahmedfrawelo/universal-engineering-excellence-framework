$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$validator = Join-Path $root 'scripts\validate-task-evidence.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ("ueef-semantic-evidence-" + [guid]::NewGuid().ToString('N') + '.json')
function Assert-Rejected($Artifact, [string]$Domain) {
  $Artifact | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temp -Encoding utf8
  $rejected = $false
  try { & $validator -Tier T3 -SelectedDomain $Domain -EvidencePath $temp | Out-Null } catch { $rejected = $true }
  if (!$rejected) { throw "Weak semantic evidence was accepted for $Domain." }
}
function New-Artifact([string]$Domain, $Fields, [string]$Kind) {
  [pscustomobject]@{
    schemaVersion=1; taskId="semantic-$Domain"; tier='T3'; repositoryRoot=$root
    selectedGates=@(); selectedDomains=@($Domain)
    domains=[pscustomobject]@{
      $Domain=[pscustomobject]@{status='PASS';fields=$Fields;evidence=@([pscustomobject]@{kind=$Kind;source='scripts/test-task-evidence-semantics.ps1';result='PASS';observedAt=[datetimeoffset]::Now.ToString('o');exitCode=0;sha256='not-used';reviewer='test automation'});residualRisks=@()}
    }
  }
}
try {
  $performanceFields=[pscustomobject]@{baseline='p95 180 ms';bottleneck='render loop';change='memoized selector';remeasurement='p95 95 ms';varianceDecision='3 runs within 4 %';budget='p95 120 ms'}
  $performance=New-Artifact 'performance' $performanceFields 'command-measurement'
  $performance | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temp -Encoding utf8
  & $validator -Tier T3 -SelectedDomain performance -EvidencePath $temp | Out-Null
  $performance.domains.performance.fields.baseline='looks fast'
  Assert-Rejected $performance 'performance'

  $testingFields=[pscustomobject]@{behaviorCoverage='acceptance behavior';edgeCoverage='empty and maximum';failureCoverage='timeout and rejection';commands='npm test';results='42 tests passed'}
  $testing=New-Artifact 'testing' $testingFields 'test-command'
  $testing | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temp -Encoding utf8
  & $validator -Tier T3 -SelectedDomain testing -EvidencePath $temp | Out-Null
  $testing.domains.testing.evidence[0].kind='opinion'
  Assert-Rejected $testing 'testing'

  $securityFields=[pscustomobject]@{assets='customer records';actors='user and admin';trustBoundaries='browser to API';threats='IDOR and injection';authorization='resource ownership';validation='schema validation';secretHandling='secret store';verification='security test suite'}
  $security=New-Artifact 'security' $securityFields 'security-audit'
  $security | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temp -Encoding utf8
  & $validator -Tier T3 -SelectedDomain security -EvidencePath $temp | Out-Null
  $security.domains.security.evidence[0].kind='confidence'
  Assert-Rejected $security 'security'
  Write-Output 'Task evidence semantic tests passed.'
} finally {
  if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
}
