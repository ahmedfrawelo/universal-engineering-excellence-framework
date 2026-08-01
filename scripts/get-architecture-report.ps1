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
  $projectPolicy = Join-Path $Root '.ueef\architecture-policy.json'
  if (Test-Path -LiteralPath $projectPolicy -PathType Leaf) { $PolicyPath = $projectPolicy }
  elseif ($Root -eq (Resolve-Path -LiteralPath $frameworkRoot).Path) { $PolicyPath = Join-Path $frameworkRoot 'config\architecture-policy.json' }
}
if ([string]::IsNullOrWhiteSpace($PolicyPath) -or !(Test-Path -LiteralPath $PolicyPath -PathType Leaf)) {
  $result = [pscustomobject]@{schemaVersion=1;repositoryRoot=$Root;status='NOT_CONFIGURED';policyPath=$null;changedFiles=@();ownerMap=@();dependencies=@();violations=@();warnings=@([pscustomobject]@{code='ARCHITECTURE_POLICY_MISSING';detail='Create .ueef/architecture-policy.json before claiming Architecture PASS.'})}
  if ($Json) { $result | ConvertTo-Json -Depth 6 } else { $result | Format-List }
  if ($FailOnViolation) { exit 2 }
  exit 0
}
$policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
if ($policy.schemaVersion -ne 1) { throw "Unsupported architecture policy schema: $($policy.schemaVersion)" }
if (!@($policy.owners).Count) { throw 'Architecture policy requires at least one owner.' }

function Test-Glob([string]$Path, [string]$Pattern) {
  $escaped = [regex]::Escape($Pattern.Replace('\','/')).Replace('\*\*','.*').Replace('\*','[^/]*')
  return $Path.Replace('\','/') -match "^$escaped$"
}
function Get-Owner([string]$Path) {
  $normalized = $Path.Replace('\','/').TrimStart('/')
  $matches = foreach ($owner in @($policy.owners)) {
    foreach ($prefix in @($owner.paths)) {
      $p = ([string]$prefix).Replace('\','/')
      if (($p.EndsWith('/') -and $normalized.StartsWith($p,[StringComparison]::OrdinalIgnoreCase)) -or (!$p.EndsWith('/') -and $normalized.Equals($p,[StringComparison]::OrdinalIgnoreCase))) {
        [pscustomobject]@{id=[string]$owner.id;length=$p.Length}
      }
    }
  }
  return @($matches | Sort-Object length -Descending | Select-Object -First 1).id
}

$files = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($item in @($ChangedFile | ForEach-Object { $_ -split ',' } | Where-Object { $_ })) { [void]$files.Add(([string]$item).Replace('\','/').TrimStart('/')) }
if (!$files.Count -and (Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath (Join-Path $Root '.git'))) {
  $previousErrorAction=$ErrorActionPreference
  $ErrorActionPreference='Continue'
  try {
    if (![string]::IsNullOrWhiteSpace($Base)) {
      $gitOutput=@(& git -C $Root diff --name-only --diff-filter=ACMR "$Base...HEAD" -- 2>$null); if($LASTEXITCODE -ne 0){throw 'Unable to inspect architecture changes from the requested base.'}
      foreach ($item in $gitOutput) { if ($item) { [void]$files.Add(([string]$item).Replace('\','/')) } }
    }
    $gitOutput=@(& git -C $Root diff --name-only --diff-filter=ACMR HEAD -- 2>$null); if($LASTEXITCODE -ne 0){throw 'Unable to inspect tracked architecture changes.'}
    foreach ($item in $gitOutput) { if ($item) { [void]$files.Add(([string]$item).Replace('\','/')) } }
    $gitOutput=@(& git -C $Root ls-files --others --exclude-standard 2>$null); if($LASTEXITCODE -ne 0){throw 'Unable to inspect untracked architecture changes.'}
    foreach ($item in $gitOutput) { if ($item) { [void]$files.Add(([string]$item).Replace('\','/')) } }
  } finally { $ErrorActionPreference=$previousErrorAction }
}

$violations = [Collections.Generic.List[object]]::new()
$warnings = [Collections.Generic.List[object]]::new()
$owners = [Collections.Generic.List[object]]::new()
$dependencies = [Collections.Generic.List[object]]::new()
$ignored = @($policy.ignoredSegments)
foreach ($relative in $files) {
  if (@($relative.Split('/') | Where-Object { $_ -in $ignored }).Count) { continue }
  $owner = Get-Owner $relative
  $owners.Add([pscustomobject]@{path=$relative;owner=if($owner){$owner}else{'unowned'}})
  if (!$owner) { $warnings.Add([pscustomobject]@{code='UNOWNED_ARCHITECTURE_PATH';path=$relative;detail='Changed path has no architecture owner.'}) }
  $extension = [IO.Path]::GetExtension($relative).ToLowerInvariant()
  $full = Join-Path $Root $relative
  if ($owner -and $extension -in @($policy.sourceExtensions) -and (Test-Path -LiteralPath $full -PathType Leaf)) {
    $content = Get-Content -LiteralPath $full -Raw
    $matches = [regex]::Matches($content, '(?m)(?:from\s+|import\s*\(|require\s*\()\s*["''](?<path>\.{1,2}/[^"'']+)["'']')
    foreach ($match in $matches) {
      $import = [string]$match.Groups['path'].Value
      $sourceDir = Split-Path -Parent $relative
      $target = [IO.Path]::GetFullPath((Join-Path (Join-Path $Root $sourceDir) $import))
      $rootPrefix = [IO.Path]::GetFullPath($Root).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
      if (!$target.StartsWith($rootPrefix,[StringComparison]::OrdinalIgnoreCase)) {
        $violations.Add([pscustomobject]@{code='DEPENDENCY_PATH_ESCAPE';path=$relative;detail="Relative import escapes repository root: $import."})
        continue
      }
      $targetRelative = $target.Substring($rootPrefix.Length).Replace('\','/')
      $targetOwner = Get-Owner $targetRelative
      $dependencies.Add([pscustomobject]@{source=$relative;sourceOwner=$owner;target=$targetRelative;targetOwner=if($targetOwner){$targetOwner}else{'unowned'}})
      if ($targetOwner) {
        $allowed = @($policy.allowedDependencies.PSObject.Properties[$owner].Value)
        if ($targetOwner -notin $allowed) { $violations.Add([pscustomobject]@{code='FORBIDDEN_DEPENDENCY';path=$relative;detail="Owner '$owner' may not depend on '$targetOwner' via $import."}) }
      }
    }
  }
}

$boundaryChanged = @($files | Where-Object { $candidate=$_; @($policy.publicBoundaryPatterns | Where-Object { Test-Glob $candidate ([string]$_) }).Count -gt 0 })
$adrChanged = @($files | Where-Object { $candidate=$_; @($policy.adrPatterns | Where-Object { Test-Glob $candidate ([string]$_) }).Count -gt 0 })
if ($policy.requireAdrForPublicBoundaryChange -and $boundaryChanged.Count -and !$adrChanged.Count) {
  $violations.Add([pscustomobject]@{code='ADR_REQUIRED';path=($boundaryChanged -join ', ');detail='A public architecture boundary changed without a matching ADR change.'})
}
$status = if ($violations.Count) {'FAIL'} elseif ($warnings.Count) {'REVIEW_REQUIRED'} else {'PASS'}
$result = [pscustomobject]@{schemaVersion=1;repositoryRoot=$Root;policyPath=(Resolve-Path -LiteralPath $PolicyPath).Path;status=$status;changedFiles=@($files|Sort-Object);ownerMap=$owners.ToArray();dependencies=$dependencies.ToArray();violations=$violations.ToArray();warnings=$warnings.ToArray()}
if ($Json) { $result | ConvertTo-Json -Depth 7 } else { $result | Format-List }
if ($FailOnViolation -and $status -ne 'PASS') { exit 2 }
