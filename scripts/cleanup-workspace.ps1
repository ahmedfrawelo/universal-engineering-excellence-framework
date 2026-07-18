param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [int]$OlderThanDays = 14,
  [switch]$Apply,
  [switch]$IncludeTrackedArtifacts
)

$ErrorActionPreference = "Stop"
$isWindowsPlatform = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
$pathComparison = if ($isWindowsPlatform) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
$repositoryManifests = @(
  "package.json", "pyproject.toml", "Cargo.toml", "go.mod", "pom.xml",
  "build.gradle", "build.gradle.kts", "composer.json", "Gemfile", "release-manifest.json"
)

function ConvertTo-CanonicalPath([string]$Path) {
  $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
  return [IO.Path]::GetFullPath($resolved.ProviderPath)
}

function Test-PathEqual([string]$Left, [string]$Right) {
  return $Left.Equals($Right, $pathComparison)
}

function Test-StrictDescendant([string]$Path, [string]$Parent) {
  $prefix = $Parent
  if (-not $prefix.EndsWith([IO.Path]::DirectorySeparatorChar)) { $prefix += [IO.Path]::DirectorySeparatorChar }
  return -not (Test-PathEqual $Path $Parent) -and $Path.StartsWith($prefix, $pathComparison)
}

$rootItem = Get-Item -LiteralPath $Root -Force -ErrorAction Stop
if (-not $rootItem.PSIsContainer) { throw "Cleanup root must be a directory: $Root" }
if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
  throw "Refusing to clean a reparse point root: $Root"
}

$resolvedRoot = ConvertTo-CanonicalPath $Root
$filesystemRoot = [IO.Path]::GetPathRoot($resolvedRoot)
if (Test-PathEqual $resolvedRoot $filesystemRoot) {
  throw "Refusing to clean a filesystem root: $resolvedRoot"
}

$userHome = [Environment]::GetFolderPath('UserProfile')
if ($userHome -and (Test-Path -LiteralPath $userHome)) {
  $resolvedHome = ConvertTo-CanonicalPath $userHome
  if (Test-PathEqual $resolvedRoot $resolvedHome) { throw "Refusing to clean the user home: $resolvedRoot" }
}

function Test-SafeMarker([string]$Path, [bool]$RequireFile) {
  if (-not (Test-Path -LiteralPath $Path)) { return $false }
  $marker = Get-Item -LiteralPath $Path -Force
  if (($marker.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
  return -not $RequireFile -or -not $marker.PSIsContainer
}

$hasGitMarker = Test-SafeMarker (Join-Path $resolvedRoot '.git') $false
$hasManifestMarker = $repositoryManifests | Where-Object {
  Test-SafeMarker (Join-Path $resolvedRoot $_) $true
} | Select-Object -First 1
if (-not $hasGitMarker -and -not $hasManifestMarker) {
  throw "Refusing to clean '$resolvedRoot': no repository marker was found."
}

$cutoff = (Get-Date).AddDays(-[Math]::Abs($OlderThanDays))
$relativeTargets = @(
  "coverage", ".nyc_output", "playwright-report", "test-results", "screenshots",
  "artifacts", ".cache", ".pytest_cache", ".angular\cache", "tmp", "temp",
  "dist", "build", "out", "publish", ".deploy", "server-upload"
)
$filePatterns = @("*.log", "*.trace", "*.har", "*.tmp")
$protected = @(".git", "node_modules", "release", "src", "app", "config", "secrets")
$protectedPaths = $protected | ForEach-Object { [IO.Path]::GetFullPath((Join-Path $resolvedRoot $_)) }
$candidates = [System.Collections.Generic.List[object]]::new()

function Test-ProtectedPath([string]$CanonicalPath) {
  foreach ($protectedPath in $protectedPaths) {
    if ((Test-PathEqual $CanonicalPath $protectedPath) -or (Test-StrictDescendant $CanonicalPath $protectedPath)) { return $true }
  }
  return $false
}

function Test-TreeContainsReparsePoint([IO.DirectoryInfo]$RootDirectory) {
  $pending = [System.Collections.Generic.Stack[IO.DirectoryInfo]]::new()
  $pending.Push($RootDirectory)
  while ($pending.Count -gt 0) {
    foreach ($child in Get-ChildItem -LiteralPath $pending.Pop().FullName -Force -ErrorAction Stop) {
      if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $true }
      if ($child.PSIsContainer) { $pending.Push($child) }
    }
  }
  return $false
}

function Get-SafeCandidate([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $item = Get-Item -LiteralPath $Path -Force
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $null }

  $ancestor = [IO.Path]::GetDirectoryName($item.FullName)
  while ($ancestor -and (Test-StrictDescendant $ancestor $resolvedRoot)) {
    $ancestorItem = Get-Item -LiteralPath $ancestor -Force
    if (($ancestorItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $null }
    $ancestor = [IO.Path]::GetDirectoryName($ancestor)
  }

  $canonical = ConvertTo-CanonicalPath $item.FullName
  if (-not (Test-StrictDescendant $canonical $resolvedRoot) -or (Test-ProtectedPath $canonical)) { return $null }

  if ($item.PSIsContainer) {
    if (Test-TreeContainsReparsePoint $item) { return $null }
  }

  return $item
}

function Test-TrackedPath([string]$RelativePath) {
  if (-not $hasGitMarker) { return $false }
  $trackedMatches = @(git -C $resolvedRoot ls-files -- $RelativePath 2>$null)
  return $LASTEXITCODE -eq 0 -and $trackedMatches.Count -gt 0
}

foreach ($relative in $relativeTargets) {
  $target = Join-Path $resolvedRoot $relative
  $item = Get-SafeCandidate $target
  if ($item -and $item.PSIsContainer -and ($IncludeTrackedArtifacts -or -not (Test-TrackedPath $relative))) {
    $candidates.Add($item)
  }
}

$pendingDirectories = [System.Collections.Generic.Stack[IO.DirectoryInfo]]::new()
$pendingDirectories.Push((Get-Item -LiteralPath $resolvedRoot -Force))
while ($pendingDirectories.Count -gt 0) {
  foreach ($child in Get-ChildItem -LiteralPath $pendingDirectories.Pop().FullName -Force -ErrorAction Stop) {
    if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
    $canonical = ConvertTo-CanonicalPath $child.FullName
    if (-not (Test-StrictDescendant $canonical $resolvedRoot) -or (Test-ProtectedPath $canonical)) { continue }
    if ($child.PSIsContainer) {
      $pendingDirectories.Push($child)
      continue
    }
    $matchesArtifactPattern = $false
    foreach ($pattern in $filePatterns) {
      if ($child.Name -like $pattern) { $matchesArtifactPattern = $true; break }
    }
    if (-not $matchesArtifactPattern -or $child.LastWriteTime -ge $cutoff) { continue }
    $relative = $canonical.Substring($resolvedRoot.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    if ($IncludeTrackedArtifacts -or -not (Test-TrackedPath $relative)) { $candidates.Add($child) }
  }
}

$unique = $candidates | Sort-Object FullName -Unique
Write-Host "Workspace cleanup root: $resolvedRoot"
Write-Host "Retention cutoff: $cutoff"
Write-Host "Candidates: $($unique.Count)"
foreach ($item in $unique) { Write-Host ("{0} {1}" -f ($(if ($item.PSIsContainer) { "DIR " } else { "FILE" }), $item.FullName) ) }

if ($Apply) {
  foreach ($item in $unique) {
    # Re-resolve and re-check immediately before each destructive operation.
    $safeItem = Get-SafeCandidate $item.FullName
    if ($safeItem) { Remove-Item -LiteralPath $safeItem.FullName -Recurse -Force }
  }
  Write-Host "Cleanup applied. Protected source/configuration paths were skipped."
} else {
  Write-Host "Dry run only. Re-run with -Apply to delete these candidates."
}
