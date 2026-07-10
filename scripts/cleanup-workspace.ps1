param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [int]$OlderThanDays = 14,
  [switch]$Apply,
  [switch]$IncludeTrackedArtifacts
)

$ErrorActionPreference = "Stop"
$resolvedRoot = (Resolve-Path $Root).Path
$cutoff = (Get-Date).AddDays(-[Math]::Abs($OlderThanDays))
$relativeTargets = @(
  "coverage", ".nyc_output", "playwright-report", "test-results", "screenshots",
  "artifacts", ".cache", ".pytest_cache", ".angular\cache", "tmp", "temp",
  "dist", "build", "out", "publish", ".deploy", "server-upload"
)
$filePatterns = @("*.log", "*.trace", "*.har", "*.tmp")
$protected = @(".git", "node_modules", "release", "src", "app", "config", "secrets")
$candidates = [System.Collections.Generic.List[object]]::new()

function Test-ProtectedPath([string]$Path) {
  $full = (Resolve-Path -LiteralPath $Path).Path
  foreach ($name in $protected) {
    $protectedPath = Join-Path $resolvedRoot $name
    if ($full -eq $protectedPath -or $full.StartsWith($protectedPath + [IO.Path]::DirectorySeparatorChar)) { return $true }
  }
  return $false
}

foreach ($relative in $relativeTargets) {
  $target = Join-Path $resolvedRoot $relative
  if ((Test-Path -LiteralPath $target -PathType Container) -and -not (Test-ProtectedPath $target)) {
    if ($IncludeTrackedArtifacts -or -not (git -C $resolvedRoot ls-files --error-unmatch -- $relative 2>$null)) {
      $candidates.Add((Get-Item -LiteralPath $target))
    }
  }
}

foreach ($pattern in $filePatterns) {
  Get-ChildItem -LiteralPath $resolvedRoot -File -Recurse -Filter $pattern -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $cutoff -and -not (Test-ProtectedPath $_.FullName) } |
    ForEach-Object { if ($IncludeTrackedArtifacts -or -not (git -C $resolvedRoot ls-files --error-unmatch -- $_.FullName.Substring($resolvedRoot.Length + 1) 2>$null)) { $candidates.Add($_) } }
}

$unique = $candidates | Sort-Object FullName -Unique
Write-Host "Workspace cleanup root: $resolvedRoot"
Write-Host "Retention cutoff: $cutoff"
Write-Host "Candidates: $($unique.Count)"
foreach ($item in $unique) { Write-Host ("{0} {1}" -f ($(if ($item.PSIsContainer) { "DIR " } else { "FILE" }), $item.FullName) ) }

if ($Apply) {
  foreach ($item in $unique) { Remove-Item -LiteralPath $item.FullName -Recurse -Force }
  Write-Host "Cleanup applied. Protected source/configuration paths were skipped."
} else {
  Write-Host "Dry run only. Re-run with -Apply to delete these candidates."
}
