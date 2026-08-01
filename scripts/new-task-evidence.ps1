[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$TaskId,
  [Parameter(Mandatory)][ValidateSet('T2','T3','T4')][string]$Tier,
  [string]$RepositoryRoot = '.',
  [string[]]$SelectedGate = @(),
  [string[]]$SelectedDomain = @(),
  [Parameter(Mandatory)][string]$OutputPath,
  [string]$RegistryPath = '',
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
if ([string]::IsNullOrWhiteSpace($RegistryPath)) { $RegistryPath = Join-Path $root 'config\enforcement-registry.json' }
$registry = Get-Content -LiteralPath $RegistryPath -Raw | ConvertFrom-Json
if ($registry.schemaVersion -ne 1) { throw 'Unsupported enforcement registry schema.' }

$gateMap=@{}
foreach ($domain in @($registry.domains)) { foreach ($gate in @($domain.gates)) { $gateMap[[string]$gate]=[string]$domain.id } }
$domains=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($domain in @($SelectedDomain | ForEach-Object { $_ -split ',' } | Where-Object { $_ })) {
  if ($domain -notin @($registry.domains.id)) { throw "Unknown enforcement domain: $domain" }
  [void]$domains.Add([string]$domain)
}
$normalizedGates=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($gateInput in @($SelectedGate | ForEach-Object { $_ -split ',' } | Where-Object { $_ })) {
  $gate=[IO.Path]::GetFileName(([string]$gateInput).Replace('/','\'))
  if (!$gateMap.ContainsKey($gate)) { throw "Selected quality gate has no enforcement mapping: $gate" }
  [void]$normalizedGates.Add($gate)
  [void]$domains.Add([string]$gateMap[$gate])
}
if ($domains.Contains('architecture')) { [void]$domains.Add('file-organization') }
if (!$domains.Count) { throw 'At least one selected gate or domain is required.' }

$domainRecords=[ordered]@{}
foreach ($domainId in @($domains | Sort-Object)) {
  $contract=@($registry.domains | Where-Object id -eq $domainId)[0]
  $fields=[ordered]@{}
  foreach ($field in @($contract.requiredFields)) { $fields[[string]$field]="replace-me: $field" }
  $domainRecords[$domainId]=[ordered]@{
    status='PENDING'
    fields=$fields
    evidence=@([ordered]@{kind='replace-me';source='replace-me';result='PENDING';observedAt='replace-me';exitCode=$null;sha256='replace-me';reviewer='replace-me'})
    residualRisks=@()
  }
}
$artifact=[ordered]@{
  schemaVersion=1
  taskId=$TaskId
  tier=$Tier
  repositoryRoot=$RepositoryRoot
  selectedGates=@($normalizedGates | Sort-Object)
  selectedDomains=@($domains | Sort-Object)
  domains=$domainRecords
}
$fullOutput=[IO.Path]::GetFullPath($OutputPath)
if ((Test-Path -LiteralPath $fullOutput) -and !$Force) { throw "Evidence artifact already exists: $fullOutput" }
$parent=Split-Path -Parent $fullOutput
if (!(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
$artifact | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $fullOutput -Encoding utf8
Write-Output $fullOutput
