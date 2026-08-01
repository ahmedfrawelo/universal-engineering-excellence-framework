[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('T0','T1','T2','T3','T4')][string]$Tier,
  [string[]]$SelectedGate = @(),
  [string[]]$SelectedDomain = @(),
  [string]$EvidencePath = '',
  [string]$RegistryPath = '',
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($RegistryPath)) { $RegistryPath = Join-Path $root 'config\enforcement-registry.json' }
if (!(Test-Path -LiteralPath $RegistryPath -PathType Leaf)) { throw "Enforcement registry not found: $RegistryPath" }
$registry = Get-Content -LiteralPath $RegistryPath -Raw | ConvertFrom-Json
if ($registry.schemaVersion -ne 1) { throw "Unsupported enforcement registry schema: $($registry.schemaVersion)" }

$gateMap = @{}
foreach ($domain in @($registry.domains)) {
  foreach ($gate in @($domain.gates)) {
    if ($gateMap.ContainsKey([string]$gate)) { throw "Quality gate is mapped more than once: $gate" }
    $gateMap[[string]$gate] = [string]$domain.id
  }
}

$domainIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($domain in @($SelectedDomain | ForEach-Object { $_ -split ',' } | Where-Object { $_ })) { [void]$domainIds.Add([string]$domain) }
foreach ($gateInput in @($SelectedGate | ForEach-Object { $_ -split ',' } | Where-Object { $_ })) {
  $gateName = [IO.Path]::GetFileName(([string]$gateInput).Replace('/','\'))
  if (!$gateMap.ContainsKey($gateName)) { throw "Selected quality gate has no enforcement mapping: $gateName" }
  [void]$domainIds.Add([string]$gateMap[$gateName])
}

$knownDomains = @($registry.domains.id)
foreach ($domainId in $domainIds) { if ($domainId -notin $knownDomains) { throw "Unknown enforcement domain: $domainId" } }
$requiresEvidence = $Tier -in @($registry.policy.appliesToTiers) -and $domainIds.Count -gt 0
if (!$requiresEvidence) {
  $result = [pscustomobject]@{schemaVersion=1;tier=$Tier;status='NOT_REQUIRED';domains=@();evidencePath=$EvidencePath}
  if ($Json) { $result | ConvertTo-Json -Depth 4 } else { $result | Format-List }
  exit 0
}

if ([string]::IsNullOrWhiteSpace($EvidencePath) -or !(Test-Path -LiteralPath $EvidencePath -PathType Leaf)) {
  throw 'Selected T2+ quality gates require a task evidence artifact.'
}
$evidence = Get-Content -LiteralPath $EvidencePath -Raw | ConvertFrom-Json
if ($evidence.schemaVersion -ne 1) { throw "Unsupported task evidence schema: $($evidence.schemaVersion)" }
if ([string]::IsNullOrWhiteSpace([string]$evidence.taskId)) { throw 'Task evidence requires taskId.' }
if ([string]::IsNullOrWhiteSpace([string]$evidence.repositoryRoot)) { throw 'Task evidence requires repositoryRoot.' }
if ([string]$evidence.tier -ne $Tier) { throw "Task evidence tier '$($evidence.tier)' does not match requested tier '$Tier'." }
$declaredDomains = @($evidence.selectedDomains | ForEach-Object { [string]$_ })
foreach ($domainId in $domainIds) { if ($domainId -notin $declaredDomains) { throw "Task evidence selectedDomains does not declare requested domain: $domainId" } }
$declaredGates = @($evidence.selectedGates | ForEach-Object { [IO.Path]::GetFileName(([string]$_).Replace('/','\')) })
foreach ($gate in $declaredGates) {
  if (!$gateMap.ContainsKey($gate)) { throw "Task evidence declares unmapped quality gate: $gate" }
  if ([string]$gateMap[$gate] -notin $declaredDomains) { throw "Task evidence gate '$gate' is missing its declared domain '$($gateMap[$gate])'." }
}
foreach ($gateInput in @($SelectedGate | ForEach-Object { $_ -split ',' } | Where-Object { $_ })) {
  $gateName=[IO.Path]::GetFileName(([string]$gateInput).Replace('/','\'))
  if ($gateName -notin $declaredGates) { throw "Task evidence selectedGates does not declare requested gate: $gateName" }
}
if ('architecture' -in $declaredDomains -and 'file-organization' -notin $declaredDomains) { throw 'Architecture evidence must also declare file-organization.' }
foreach ($declaredDomain in $declaredDomains) {
  if ($declaredDomain -notin $knownDomains) { throw "Task evidence declares unknown domain: $declaredDomain" }
  [void]$domainIds.Add($declaredDomain)
}

function Test-SubstantiveValue($Value) {
  if ($null -eq $Value) { return $false }
  if ($Value -is [string]) { return ![string]::IsNullOrWhiteSpace($Value) -and $Value -notmatch '^(replace-me|replace-with-|todo|tbd)' }
  if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) { return @($Value).Count -gt 0 }
  return $true
}

function Test-MeasuredValue($Value) {
  if (!(Test-SubstantiveValue $Value)) { return $false }
  $text = if ($Value -is [string]) { $Value } else { $Value | ConvertTo-Json -Depth 5 -Compress }
  return $text -match '(?i)\b\d+(?:[.,]\d+)?\s*(?:ms|s|sec|seconds?|minutes?|%|kb|mb|gb|bytes?|req(?:uests?)?/?s|ops/?s|fps|score|rows?|queries?|cpu|memory)\b'
}

function Assert-DomainSemantics($DomainId, $Record, $EvidenceItems) {
  if ($DomainId -eq 'performance') {
    foreach ($field in @('baseline','remeasurement','budget')) {
      if (!(Test-MeasuredValue $Record.fields.PSObject.Properties[$field].Value)) { throw "Performance field '$field' requires a numeric value with a unit." }
    }
  }
  $kindText = (@($EvidenceItems | ForEach-Object { [string]$_.kind }) -join ' ')
  $requiredKindPattern = switch ($DomainId) {
    'testing' { 'command|test|report' }
    'security' { 'threat|security|command|report|review|audit' }
    'accessibility' { 'accessibility|browser|command|report|screenshot|audit' }
    'uiux' { 'visual|browser|screenshot|artifact|review' }
    'code-quality' { 'command|lint|analysis|report|review' }
    default { '' }
  }
  if ($requiredKindPattern -and $kindText -notmatch $requiredKindPattern) { throw "Task evidence domain '$DomainId' lacks an appropriate evidence kind." }
}

function Assert-EvidenceProvenance($Item, [string]$DomainId) {
  $kind=([string]$Item.kind).ToLowerInvariant()
  $observedAt=[string]$Item.observedAt
  $timestamp=[datetimeoffset]::MinValue
  if (!(Test-SubstantiveValue $observedAt) -or ![datetimeoffset]::TryParse($observedAt,[ref]$timestamp)) { throw "Evidence in '$DomainId' requires a valid observedAt timestamp." }
  if ($timestamp -gt [datetimeoffset]::Now.AddMinutes(5)) { throw "Evidence in '$DomainId' has a future observedAt timestamp." }
  if ($kind -match 'command|test') {
    if ($null -eq $Item.exitCode -or [int]$Item.exitCode -ne 0) { throw "Command/test evidence in '$DomainId' requires exitCode 0." }
    return
  }
  if ($kind -match 'artifact|report|screenshot|file') {
    $sourcePath=[string]$Item.source
    if (![IO.Path]::IsPathRooted($sourcePath)) { $sourcePath=Join-Path ([string]$evidence.repositoryRoot) $sourcePath }
    if (!(Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Evidence file in '$DomainId' does not exist: $sourcePath" }
    if (!(Test-SubstantiveValue ([string]$Item.sha256))) { throw "Evidence file in '$DomainId' requires sha256." }
    $actual=(Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    if ($actual -ne ([string]$Item.sha256).ToUpperInvariant()) { throw "Evidence file hash mismatch in '$DomainId'." }
    return
  }
  if ($kind -match 'review|audit') {
    if (!(Test-SubstantiveValue ([string]$Item.reviewer))) { throw "Review evidence in '$DomainId' requires reviewer." }
    return
  }
  throw "Evidence kind in '$DomainId' is not a supported provenance category: $($Item.kind)"
}

$validated = [Collections.Generic.List[object]]::new()
foreach ($domainId in $domainIds) {
  $contract = @($registry.domains | Where-Object id -eq $domainId)[0]
  $record = $evidence.domains.PSObject.Properties[$domainId].Value
  if ($null -eq $record) { throw "Task evidence is missing selected domain: $domainId" }
  if ([string]$record.status -ne 'PASS') { throw "Selected enforcement domain did not PASS: $domainId" }
  foreach ($field in @($contract.requiredFields)) {
    $property = $record.fields.PSObject.Properties[[string]$field]
    if ($null -eq $property -or !(Test-SubstantiveValue $property.Value)) { throw "Task evidence domain '$domainId' is missing substantive field '$field'." }
  }
  if ($domainId -in @('architecture','file-organization')) {
    $reportPath = [string]$record.fields.automatedReport
    if (![IO.Path]::IsPathRooted($reportPath)) { $reportPath = Join-Path ([string]$evidence.repositoryRoot) $reportPath }
    if (!(Test-Path -LiteralPath $reportPath -PathType Leaf)) { throw "$domainId automated report not found: $reportPath" }
    $automatedReport = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if ($automatedReport.schemaVersion -ne 1) { throw "Unsupported $domainId report schema." }
    if ([string]$automatedReport.status -ne 'PASS') { throw "$domainId automated report did not PASS: $($automatedReport.status)" }
  }
  $evidenceItems = @($record.evidence)
  if (!$evidenceItems.Count) { throw "Task evidence domain '$domainId' has no evidence items." }
  foreach ($item in $evidenceItems) {
    if (!(Test-SubstantiveValue ([string]$item.kind)) -or !(Test-SubstantiveValue ([string]$item.source)) -or [string]$item.result -ne 'PASS') {
      throw "Task evidence domain '$domainId' contains invalid or non-passing evidence."
    }
    Assert-EvidenceProvenance $item $domainId
  }
  Assert-DomainSemantics $domainId $record $evidenceItems
  foreach ($risk in @($record.residualRisks)) {
    if ([string]::IsNullOrWhiteSpace([string]$risk.owner) -or [string]::IsNullOrWhiteSpace([string]$risk.mitigation) -or [string]::IsNullOrWhiteSpace([string]$risk.trigger)) {
      throw "Residual risk in '$domainId' requires owner, mitigation, and trigger."
    }
  }
  $validated.Add([pscustomobject]@{domain=$domainId;mode=[string]$contract.mode;status='PASS';evidenceItems=$evidenceItems.Count})
}

$result = [pscustomobject]@{schemaVersion=1;tier=$Tier;status='PASS';taskId=[string]$evidence.taskId;repositoryRoot=[string]$evidence.repositoryRoot;domains=$validated.ToArray();evidencePath=(Resolve-Path -LiteralPath $EvidencePath).Path}
if ($Json) { $result | ConvertTo-Json -Depth 5 } else { $result | Format-List }
