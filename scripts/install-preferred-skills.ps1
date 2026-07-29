[CmdletBinding()]
param(
  [string]$CodexHome = '',
  [string]$PythonPath = '',
  [string[]]$Skill = @()
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'resolve-codex-home.ps1')
$CodexHome = Resolve-CodexHome -Override $CodexHome
$manifestPath = Join-Path $root 'config\preferred-skills.json'
if (!(Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Preferred skills manifest not found: $manifestPath" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1) { throw "Unsupported preferred skills schema: $($manifest.schemaVersion)" }

$installer = Join-Path $CodexHome 'skills\.system\skill-installer\scripts\install-skill-from-github.py'
if (!(Test-Path -LiteralPath $installer -PathType Leaf)) { throw "Skill installer not found: $installer" }

if ([string]::IsNullOrWhiteSpace($PythonPath)) {
  $bundledCandidates = @()
  if ($env:USERPROFILE) { $bundledCandidates += (Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe') }
  if ($env:LOCALAPPDATA) { $bundledCandidates += (Join-Path $env:LOCALAPPDATA 'codex-runtimes\codex-primary-runtime\dependencies\python\python.exe') }
  foreach ($bundledPython in $bundledCandidates) {
    if (Test-Path -LiteralPath $bundledPython -PathType Leaf) { $PythonPath = $bundledPython; break }
  }
  if ([string]::IsNullOrWhiteSpace($PythonPath)) {
    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCommand) { $PythonPath = $pythonCommand.Source }
  }
}
if ([string]::IsNullOrWhiteSpace($PythonPath) -or !(Test-Path -LiteralPath $PythonPath -PathType Leaf)) {
  throw 'Python was not found. Pass -PythonPath or install a supported Python runtime.'
}

$all = @($manifest.preferred)
if ($Skill.Count) {
  $unknown = @($Skill | Where-Object { $_ -notin @($all.id) })
  if ($unknown.Count) { throw "Unknown preferred skill(s): $($unknown -join ', ')" }
  $all = @($all | Where-Object { $_.id -in $Skill })
}

$destination = Join-Path $CodexHome 'skills'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$results = [Collections.Generic.List[object]]::new()
foreach ($entry in $all) {
  $skillRoot = Join-Path $destination ([string]$entry.id)
  $skillFile = Join-Path $skillRoot 'SKILL.md'
  if (Test-Path -LiteralPath $skillFile -PathType Leaf) {
    $results.Add([pscustomobject]@{ skill=$entry.id; status='ALREADY_INSTALLED'; source=$entry.source.repository; ref=$entry.source.ref })
    continue
  }
  if (Test-Path -LiteralPath $skillRoot) { throw "Refusing to overwrite incomplete skill directory: $skillRoot" }
  $installName = if ($entry.source.PSObject.Properties.Name -contains 'installName') { [string]$entry.source.installName } else { [string]$entry.id }
  & $PythonPath $installer --repo ([string]$entry.source.repository) --ref ([string]$entry.source.ref) --path ([string]$entry.source.path) --name $installName --dest $destination
  if ($LASTEXITCODE -ne 0) { throw "Preferred skill installation failed for $($entry.id) with exit code $LASTEXITCODE" }
  if (!(Test-Path -LiteralPath $skillFile -PathType Leaf)) { throw "Installer completed without creating $skillFile" }
  $results.Add([pscustomobject]@{ skill=$entry.id; status='INSTALLED'; source=$entry.source.repository; ref=$entry.source.ref })
}

$results | Sort-Object skill | Format-Table skill,status,source,ref -AutoSize
Write-Output "Preferred skills ready: $($results.Count)"
