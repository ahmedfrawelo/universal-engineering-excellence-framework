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
if ($manifest.schemaVersion -notin @(1,2)) { throw "Unsupported preferred skills schema: $($manifest.schemaVersion)" }

$installer = Join-Path $CodexHome 'skills\.system\skill-installer\scripts\install-skill-from-github.py'

$all = @($manifest.preferred)
if ($Skill.Count) {
  $unknown = @($Skill | Where-Object { $_ -notin @($all.id) })
  if ($unknown.Count) { throw "Unknown preferred skill(s): $($unknown -join ', ')" }
  $all = @($all | Where-Object { $_.id -in $Skill })
}

$needsGithubInstaller = @($all | Where-Object { !$_.source.kind -or $_.source.kind -ne 'bundled' }).Count -gt 0
if ($needsGithubInstaller) {
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
}

$destination = Join-Path $CodexHome 'skills'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$results = [Collections.Generic.List[object]]::new()

function Set-ManualOnlyPolicy([string]$SkillFile) {
  $content = [IO.File]::ReadAllText($SkillFile)
  if ($content -match '(?m)^disable-model-invocation:\s*true\s*$') { return }
  $updated = [regex]::Replace($content, '(?m)^(description:.*)$', "$1`ndisable-model-invocation: true", 1)
  if ($updated -eq $content) { throw "Cannot apply manual-only policy to $SkillFile" }
  [IO.File]::WriteAllText($SkillFile, $updated, [Text.UTF8Encoding]::new($false))
}

foreach ($entry in $all) {
  $skillRoot = Join-Path $destination ([string]$entry.id)
  $skillFile = Join-Path $skillRoot 'SKILL.md'
  $sourceKind = if ($entry.source.PSObject.Properties.Name -contains 'kind') { [string]$entry.source.kind } else { 'github' }
  if ($sourceKind -eq 'bundled') {
    $bundledRoot = Join-Path $root ([string]$entry.source.path)
    if (!(Test-Path -LiteralPath (Join-Path $bundledRoot 'SKILL.md') -PathType Leaf)) { throw "Bundled skill source missing: $bundledRoot" }
    New-Item -ItemType Directory -Path $skillRoot -Force | Out-Null
    foreach ($item in Get-ChildItem -LiteralPath $bundledRoot -Force) {
      Copy-Item -LiteralPath $item.FullName -Destination $skillRoot -Recurse -Force
    }
    $status = 'SYNCED_BUNDLED'
  } elseif (Test-Path -LiteralPath $skillFile -PathType Leaf) {
    $status = 'ALREADY_INSTALLED'
  } else {
    if (Test-Path -LiteralPath $skillRoot) { throw "Refusing to overwrite incomplete skill directory: $skillRoot" }
    $installName = if ($entry.source.PSObject.Properties.Name -contains 'installName') { [string]$entry.source.installName } else { [string]$entry.id }
    & $PythonPath $installer --repo ([string]$entry.source.repository) --ref ([string]$entry.source.ref) --path ([string]$entry.source.path) --name $installName --dest $destination
    if ($LASTEXITCODE -ne 0) { throw "Preferred skill installation failed for $($entry.id) with exit code $LASTEXITCODE" }
    $status = 'INSTALLED'
  }
  if (!(Test-Path -LiteralPath $skillFile -PathType Leaf)) { throw "Installer completed without creating $skillFile" }
  if ($sourceKind -eq 'github-manual-only') { Set-ManualOnlyPolicy $skillFile }
  $sourceName = if ($sourceKind -eq 'bundled') { 'UEEF bundled source' } else { [string]$entry.source.repository }
  $sourceRef = if ($sourceKind -eq 'bundled') { 'runtime-versioned' } else { [string]$entry.source.ref }
  $results.Add([pscustomobject]@{ skill=$entry.id; status=$status; source=$sourceName; ref=$sourceRef })
}

$results | Sort-Object skill | Format-Table skill,status,source,ref -AutoSize
Write-Output "Preferred skills ready: $($results.Count)"
