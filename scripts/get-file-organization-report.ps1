[CmdletBinding()]
param(
  [string]$Root = '.',
  [string]$Base = '',
  [string[]]$ChangedFile = @(),
  [string]$PolicyPath = '',
  [switch]$FailOnViolation,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$frameworkRoot = Split-Path -Parent $PSScriptRoot
$Root = (Resolve-Path -LiteralPath $Root).Path
if ([string]::IsNullOrWhiteSpace($PolicyPath)) {
  $projectPolicy = Join-Path $Root '.ueef\file-organization-policy.json'
  $PolicyPath = if (Test-Path -LiteralPath $projectPolicy -PathType Leaf) { $projectPolicy } else { Join-Path $frameworkRoot 'config\file-organization-policy.json' }
}
if (!(Test-Path -LiteralPath $PolicyPath -PathType Leaf)) { throw "File organization policy not found: $PolicyPath" }
$policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
if ($policy.schemaVersion -ne 1) { throw "Unsupported file organization policy schema: $($policy.schemaVersion)" }

$files = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($item in @($ChangedFile | ForEach-Object { $_ -split ',' } | Where-Object { $_ })) { [void]$files.Add(([string]$item).Replace('\','/').TrimStart('/')) }
if (!$files.Count) {
  $git = Get-Command git -ErrorAction SilentlyContinue
  if ($git -and (Test-Path -LiteralPath (Join-Path $Root '.git'))) {
    $previousErrorAction=$ErrorActionPreference
    $ErrorActionPreference='Continue'
    try {
      if (![string]::IsNullOrWhiteSpace($Base)) {
        $gitOutput=@(& $git.Source -C $Root diff --name-only --diff-filter=ACMR "$Base...HEAD" -- 2>$null); if($LASTEXITCODE -ne 0){throw 'Unable to inspect file-organization changes from the requested base.'}
        foreach ($item in $gitOutput) { if ($item) { [void]$files.Add(([string]$item).Replace('\','/')) } }
      }
      $gitOutput=@(& $git.Source -C $Root diff --name-only --diff-filter=ACMR HEAD -- 2>$null); if($LASTEXITCODE -ne 0){throw 'Unable to inspect tracked file-organization changes.'}
      foreach ($item in $gitOutput) { if ($item) { [void]$files.Add(([string]$item).Replace('\','/')) } }
      $gitOutput=@(& $git.Source -C $Root ls-files --others --exclude-standard 2>$null); if($LASTEXITCODE -ne 0){throw 'Unable to inspect untracked file-organization changes.'}
      foreach ($item in $gitOutput) { if ($item) { [void]$files.Add(([string]$item).Replace('\','/')) } }
    } finally { $ErrorActionPreference=$previousErrorAction }
  }
}

$violations = [Collections.Generic.List[object]]::new()
$warnings = [Collections.Generic.List[object]]::new()
$owners = [Collections.Generic.List[object]]::new()
$ignored = @($policy.ignoredSegments)
foreach ($relative in $files) {
  $segments = $relative.Split('/')
  if (@($segments | Where-Object { $_ -in $ignored }).Count) { continue }
  $full = [IO.Path]::GetFullPath((Join-Path $Root $relative))
  $rootPrefix = [IO.Path]::GetFullPath($Root).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
  if (!$full.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    $violations.Add([pscustomobject]@{code='PATH_ESCAPE';path=$relative;detail='Changed file escapes repository root.'})
    continue
  }
  $parent = [IO.Path]::GetDirectoryName($relative.Replace('/',[IO.Path]::DirectorySeparatorChar))
  $owner = if ([string]::IsNullOrWhiteSpace($parent)) { 'repository-root' } else { $parent.Replace('\','/') }
  $owners.Add([pscustomobject]@{path=$relative;owner=$owner})
  $extension = [IO.Path]::GetExtension($relative).ToLowerInvariant()
  $isSource = $extension -in @($policy.sourceExtensions)
  if ($isSource -and $segments.Count -eq 1 -and [IO.Path]::GetFileName($relative) -notin @($policy.allowedRootFiles)) {
    $violations.Add([pscustomobject]@{code='UNOWNED_ROOT_SOURCE';path=$relative;detail='Source file is placed at repository root without an allowed entrypoint policy.'})
  }
  foreach ($segment in $segments[0..([Math]::Max(0,$segments.Count-2))]) {
    if ($segment.ToLowerInvariant() -in @($policy.bannedDirectoryNames)) {
      $violations.Add([pscustomobject]@{code='GENERIC_DUMP_FOLDER';path=$relative;detail="Changed file is under banned generic folder '$segment'."})
      break
    }
  }
  if (Test-Path -LiteralPath $full -PathType Leaf) {
    $lineCount = @(Get-Content -LiteralPath $full).Count
    if ($lineCount -gt [int]$policy.largeFileLines) {
      $warnings.Add([pscustomobject]@{code='OVERSIZED_CHANGED_FILE';path=$relative;detail="$lineCount lines exceeds review threshold $($policy.largeFileLines)."})
    }
  }
}

$status = if ($violations.Count) { 'FAIL' } elseif ($warnings.Count) { 'REVIEW_REQUIRED' } else { 'PASS' }
$result = [pscustomobject]@{
  schemaVersion = 1
  repositoryRoot = $Root
  policyPath = (Resolve-Path -LiteralPath $PolicyPath).Path
  status = $status
  changedFiles = @($files | Sort-Object)
  ownerMap = $owners.ToArray()
  violations = $violations.ToArray()
  warnings = $warnings.ToArray()
  manualReviews = @('mixed-responsibility review','existing-owner reuse review','shared capability duplication review')
}
if ($Json) { $result | ConvertTo-Json -Depth 6 } else { $result | Format-List }
if ($FailOnViolation -and $violations.Count) { exit 2 }
