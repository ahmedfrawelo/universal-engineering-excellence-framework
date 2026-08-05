param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('build', 'query', 'path', 'explain', 'affected', 'status', 'doctor')]
  [string]$Command,
  [string]$Root = (Get-Location).Path,
  [string]$Query,
  [string]$From,
  [string]$To,
  [ValidateRange(1, 500)]
  [int]$MaxItems = 50,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$frameworkRoot = Split-Path -Parent $PSScriptRoot
$engineRoot = Join-Path $frameworkRoot 'engines\repository-intelligence'

if (!(Test-Path -LiteralPath $Root -PathType Container)) { throw "Repository root does not exist: $Root" }
if (!(Test-Path -LiteralPath (Join-Path $engineRoot 'UEEF-UPSTREAM.json') -PathType Leaf)) { throw "Embedded repository intelligence engine is incomplete: $engineRoot" }
if (!(Get-Command uv -ErrorAction SilentlyContinue)) { throw "uv is required to run repository intelligence. Install uv and retry." }

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$venvRoot = Join-Path $engineRoot '.venv'
$syncMarker = Join-Path $venvRoot '.ueef-sync-signature.ps1'
$entryExecutable = Join-Path $venvRoot 'Scripts\ueef-repository-intelligence.exe'
$dependencyFiles = @('pyproject.toml', 'uv.lock') | ForEach-Object { Join-Path $engineRoot $_ }
$dependencySignature = (@(
  "engine-root=$engineRoot"
  $dependencyFiles | ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash }
) -join ':')
$lockHasher = [Security.Cryptography.SHA256]::Create()
try { $lockKey = ([BitConverter]::ToString($lockHasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($engineRoot))).Replace('-', '').Substring(0,16)) } finally { $lockHasher.Dispose() }
$syncLockPath = Join-Path ([IO.Path]::GetTempPath()) "ueef-repository-intelligence-$lockKey.lock"
$syncLock = $null
$lockDeadline = [DateTime]::UtcNow.AddSeconds(45)
while ($null -eq $syncLock -and [DateTime]::UtcNow -lt $lockDeadline) {
  try { $syncLock = [IO.File]::Open($syncLockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
  catch [IO.IOException] { Start-Sleep -Milliseconds 100 }
}
if ($null -eq $syncLock) { throw 'Timed out waiting for the repository-intelligence dependency bootstrap lock.' }

$previousLinkMode = $env:UV_LINK_MODE
try {
  $env:UV_LINK_MODE = 'copy'
  $installedSignature = if (Test-Path -LiteralPath $syncMarker -PathType Leaf) { [IO.File]::ReadAllText($syncMarker, [Text.Encoding]::UTF8).Trim() } else { '' }
  $needsSync = !(Test-Path -LiteralPath $entryExecutable -PathType Leaf) -or $installedSignature -cne $dependencySignature
  if ($needsSync) {
    $previousErrorAction = $ErrorActionPreference
    try {
      $ErrorActionPreference = 'Continue'
      $syncOutput = & uv sync --frozen --no-dev --project $engineRoot 2>&1 | Out-String
      $syncExitCode = $LASTEXITCODE
    } finally {
      $ErrorActionPreference = $previousErrorAction
    }
    if ($syncExitCode -ne 0) { throw "Repository intelligence dependency bootstrap failed with exit code ${syncExitCode}: $($syncOutput.Trim())" }
    if ($syncOutput) { Write-Verbose $syncOutput.Trim() }
    [IO.File]::WriteAllText($syncMarker, $dependencySignature + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
  }
} finally {
  $syncLock.Dispose()
  $env:UV_LINK_MODE = $previousLinkMode
}

$arguments = @(
  '--root', $resolvedRoot,
  '--max-items', $MaxItems.ToString()
)
if ($Query) { $arguments += @('--query', $Query) }
if ($From) { $arguments += @('--from', $From) }
if ($To) { $arguments += @('--to', $To) }
if ($Json) { $arguments += '--json' }

$previousLinkMode = $env:UV_LINK_MODE
try {
  $env:UV_LINK_MODE = 'copy'
  & $entryExecutable $Command @arguments
  if ($LASTEXITCODE -ne 0) { throw "Repository intelligence command failed with exit code $LASTEXITCODE." }
} finally {
  $env:UV_LINK_MODE = $previousLinkMode
}
