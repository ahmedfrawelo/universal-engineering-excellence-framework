$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$registryPath = Join-Path $root 'config\enforcement-registry.json'
$registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
if ($registry.schemaVersion -ne 1) { throw 'Unsupported enforcement registry schema.' }
if (!(Test-Path -LiteralPath (Join-Path $root ([string]$registry.policy.validator)) -PathType Leaf)) { throw 'Enforcement validator is missing.' }
if (!(Test-Path -LiteralPath (Join-Path $root ([string]$registry.policy.template)) -PathType Leaf)) { throw 'Task evidence template is missing.' }

$mapped = [Collections.Generic.List[string]]::new()
foreach ($domain in @($registry.domains)) {
  if ([string]::IsNullOrWhiteSpace([string]$domain.id) -or [string]::IsNullOrWhiteSpace([string]$domain.mode) -or !@($domain.requiredFields).Count) { throw 'Invalid enforcement domain declaration.' }
  foreach ($gate in @($domain.gates)) {
    if ($mapped.Contains([string]$gate)) { throw "Duplicate gate mapping: $gate" }
    $mapped.Add([string]$gate)
  }
}
$gateRoot = Join-Path $root 'framework\12-delivery-quality/04-quality-gates'
$expected = @(Get-ChildItem -LiteralPath $gateRoot -File -Filter '*.md' | Where-Object { $_.Name -notin @($registry.ignoredGateFiles) } | Select-Object -ExpandProperty Name)
$missing = @($expected | Where-Object { $_ -notin $mapped })
$extra = @($mapped | Where-Object { $_ -notin $expected })
if ($missing.Count -or $extra.Count) { throw "Enforcement gate coverage mismatch. Missing: $($missing -join ', '); Extra: $($extra -join ', ')" }

$validator = Join-Path $root 'scripts\validate-task-evidence.ps1'
$validatorText = Get-Content -LiteralPath $validator -Raw
$generatorText = Get-Content -LiteralPath (Join-Path $root 'scripts\new-task-evidence.ps1') -Raw
if (($validatorText + $generatorText) -match "GetFileName\(.*Replace\('/','\\\\'\)") { throw 'Quality-gate leaf extraction is platform-specific.' }
function Assert-Rejected([hashtable]$Arguments) {
  $rejected = $false
  try { & $validator @Arguments | Out-Null } catch { $rejected = $true }
  if (!$rejected) { throw "Evidence case was incorrectly accepted: $($Arguments | ConvertTo-Json -Compress)" }
}
& $validator -Tier T1 -SelectedDomain architecture | Out-Null
Assert-Rejected @{Tier='T2';SelectedDomain='architecture'}
Assert-Rejected @{Tier='T2';SelectedGate='framework/12-delivery-quality/04-quality-gates/architecture-gate.md';EvidencePath=(Join-Path $root 'framework\21-framework-resources/01-templates\task-evidence-template.json')}

$fixture = Get-Content -LiteralPath (Join-Path $root 'framework\21-framework-resources/01-templates\task-evidence-template.json') -Raw | ConvertFrom-Json
$fixture.taskId = 'enforcement-test'
$fixture.repositoryRoot = $root
$fixture.domains.architecture.evidence[0].kind = 'command'
$fixture.domains.architecture.evidence[0].source = 'scripts/test-enforcement-coverage.ps1'
$fixture.domains.architecture.evidence[0].result = 'PASS'
$fixture.domains.architecture.evidence[0].observedAt = [datetimeoffset]::Now.ToString('o')
$fixture.domains.architecture.evidence[0].exitCode = 0
$fixture.domains.'file-organization'.evidence[0].kind = 'review'
$fixture.domains.'file-organization'.evidence[0].source = 'changed-file inventory review'
$fixture.domains.'file-organization'.evidence[0].result = 'PASS'
$fixture.domains.'file-organization'.evidence[0].observedAt = [datetimeoffset]::Now.ToString('o')
$fixture.domains.'file-organization'.evidence[0].reviewer = 'test automation'
$temp = Join-Path ([IO.Path]::GetTempPath()) ("ueef-task-evidence-" + [guid]::NewGuid().ToString('N') + '.json')
$reportTemp = Join-Path ([IO.Path]::GetTempPath()) ("ueef-file-organization-report-" + [guid]::NewGuid().ToString('N') + '.json')
$architectureReportTemp = Join-Path ([IO.Path]::GetTempPath()) ("ueef-architecture-report-" + [guid]::NewGuid().ToString('N') + '.json')
try {
  & (Join-Path $root 'scripts\get-file-organization-report.ps1') -Root $root -ChangedFile 'scripts/test-enforcement-coverage.ps1' -Json | Set-Content -LiteralPath $reportTemp -Encoding utf8
  & (Join-Path $root 'scripts\get-architecture-report.ps1') -Root $root -ChangedFile 'scripts/test-enforcement-coverage.ps1' -Json | Set-Content -LiteralPath $architectureReportTemp -Encoding utf8
  $fixture.domains.architecture.fields.automatedReport = $architectureReportTemp
  $fixture.domains.'file-organization'.fields.automatedReport = $reportTemp
  $fixture | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temp -Encoding utf8
  $pass = & $validator -Tier T3 -SelectedGate 'framework/12-delivery-quality/04-quality-gates/architecture-gate.md' -SelectedDomain file-organization -EvidencePath $temp -Json | ConvertFrom-Json
  if ($pass.status -ne 'PASS' -or @($pass.domains).Count -ne 2) { throw 'Architecture and file organization evidence did not pass.' }
  $fixture.domains.architecture.fields.dependencyDirection = ''
  $fixture | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temp -Encoding utf8
  Assert-Rejected @{Tier='T3';SelectedDomain='architecture';EvidencePath=$temp}
} finally {
  if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
  if (Test-Path -LiteralPath $reportTemp) { Remove-Item -LiteralPath $reportTemp -Force }
  if (Test-Path -LiteralPath $architectureReportTemp) { Remove-Item -LiteralPath $architectureReportTemp -Force }
}

$loader = Get-Content -LiteralPath (Join-Path $root 'UEEF-LOADER.md') -Raw
$sync = Get-Content -LiteralPath (Join-Path $root 'scripts\sync-runtime.ps1') -Raw
foreach($text in @($loader,$sync)) {
  foreach($required in @('current understanding','current step','current-step percent','overall percent','new evidence','current action','next gate')) {
    if($text -notmatch [regex]::Escape($required)){throw "Strict long-goal progress contract is missing '$required' in source or generated AGENTS policy."}
  }
  foreach($required in @('goal review','best feasible','task-caused regressions','unrelated findings','stop without')) {
    if($text -notmatch [regex]::Escape($required)){throw "Completion-review contract is missing '$required' in source or generated AGENTS policy."}
  }
  foreach($required in @('actual implementation','untraced implementation','goal update','resume point','FUTURE_STEP')) {
    if($text -notmatch [regex]::Escape($required)){throw "Goal update or actual comparison contract is missing '$required' in source or generated AGENTS policy."}
  }
}

Write-Output "Enforcement coverage tests passed ($($registry.domains.Count) domains, $($mapped.Count) quality gates)."
