param([string]$Root = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$manifest = Get-Content -LiteralPath (Join-Path $rootPath 'release-manifest.json') -Raw | ConvertFrom-Json
$version = [string]$manifest.version
$releaseDate = [string]$manifest.releaseDate

if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "Invalid manifest version: $version" }
try {
  [datetime]::ParseExact($releaseDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) | Out-Null
} catch { throw "Invalid manifest release date: $releaseDate" }

function Assert-ContainsLiteral([string]$RelativePath, [string]$Expected) {
  $path = Join-Path $rootPath $RelativePath
  if (!(Test-Path -LiteralPath $path)) { throw "Missing release file: $RelativePath" }
  if (!(Get-Content -LiteralPath $path -Raw).Contains($Expected)) {
    throw "$RelativePath is not aligned with release $version; missing: $Expected"
  }
}

Assert-ContainsLiteral 'VERSION.md' "version: $version."
Assert-ContainsLiteral 'README.md' "current release is $version"
Assert-ContainsLiteral 'QUICK_START.md' "current release is $version"
Assert-ContainsLiteral 'INSTALL.md' "current release is $version"
Assert-ContainsLiteral 'CHANGELOG.md' "through ``v$version``"
Assert-ContainsLiteral 'CHANGELOG.md' "## $version - $releaseDate"

$expectedNotes = "docs/releases/v$version.md"
if ([string]$manifest.releaseNotes -ne $expectedNotes) { throw "Manifest releaseNotes must be $expectedNotes" }
Assert-ContainsLiteral $expectedNotes "# UEEF $version"
Assert-ContainsLiteral $expectedNotes "Release date: $releaseDate"
$markdownCount = @(Get-ChildItem -LiteralPath $rootPath -Recurse -File -Filter '*.md' | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }).Count
if ([int]$manifest.trackedMarkdownFiles -ne $markdownCount) { throw "Manifest Markdown inventory mismatch: $($manifest.trackedMarkdownFiles) != $markdownCount" }

Write-Host "Release consistency tests passed for $version"
