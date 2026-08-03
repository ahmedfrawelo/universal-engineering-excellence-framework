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
$vendorRoot = Join-Path $frameworkRoot 'vendor\repository-intelligence-engine'

if (!(Test-Path -LiteralPath $Root -PathType Container)) { throw "Repository root does not exist: $Root" }
if (!(Test-Path -LiteralPath (Join-Path $vendorRoot 'UEEF-VENDOR.json') -PathType Leaf)) { throw "Vendored repository intelligence engine is incomplete: $vendorRoot" }
if (!(Get-Command uv -ErrorAction SilentlyContinue)) { throw "uv is required to run repository intelligence. Install uv and retry." }

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$arguments = @(
  'run', '--frozen', '--no-dev', '--project', $vendorRoot,
  'ueef-repository-intelligence', $Command,
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
  & uv @arguments
  if ($LASTEXITCODE -ne 0) { throw "Repository intelligence command failed with exit code $LASTEXITCODE." }
} finally {
  $env:UV_LINK_MODE = $previousLinkMode
}
