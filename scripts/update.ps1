param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$gitRoot = $resolvedRoot

git -C $gitRoot rev-parse --is-inside-work-tree 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
  $statePath = Join-Path (Split-Path -Parent $resolvedRoot) 'UEEF-ACTIVE.json'
  if (!(Test-Path -LiteralPath $statePath)) { throw 'This runtime is not a Git checkout and has no UEEF-ACTIVE.json source metadata.' }
  $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
  $gitRoot = [string]$state.sourceRepositoryPath
  if ([string]::IsNullOrWhiteSpace($gitRoot) -or !(Test-Path -LiteralPath (Join-Path $gitRoot '.git'))) { throw "Recorded source repository is unavailable: $gitRoot" }
}

git -C $gitRoot pull --ff-only
if ($LASTEXITCODE -ne 0) { throw 'Git update failed.' }

if ($gitRoot -ne $resolvedRoot) {
  $statePath = Join-Path (Split-Path -Parent $resolvedRoot) 'UEEF-ACTIVE.json'
  $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
  & (Join-Path $gitRoot 'scripts\sync-runtime.ps1') -SourcePath $gitRoot -CodexHome ([string]$state.codexHome) -Agent ([string]$state.agent)
} else {
  Write-Host 'Repository updated. Re-run installer for each agent.'
}
