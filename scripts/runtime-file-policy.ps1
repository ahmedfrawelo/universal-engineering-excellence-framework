$script:UeefOwnedDirectories = @('framework','scripts','docs','examples','tools','assets','config','engines')
$script:UeefOwnedRootFiles = @(
  '.gitattributes','.gitignore','BUILD_PROGRESS.md','CHANGELOG.md','CODE_OF_CONDUCT.md',
  'CONTRIBUTING.md','INSTALL.md','LICENSE','QUICK_START.md','README.md','ROADMAP.md',
  'SECURITY.md','VERSION.md','release-manifest.json'
)
$script:UeefRuntimeGeneratedSegments = @('.venv','build','graphifyy.egg-info','__pycache__','.pytest_cache','.hypothesis','.ruff_cache','.mypy_cache')

function Test-UeefRuntimeGeneratedRelativePath {
  param([Parameter(Mandatory)][string]$RelativePath)
  $segments = $RelativePath.Replace('\','/').TrimStart('/').Split('/')
  return $segments.Count -ge 3 -and $segments[0] -ceq 'engines' -and $segments[1] -ceq 'repository-intelligence' -and
    @($segments | Where-Object { $_ -in $script:UeefRuntimeGeneratedSegments }).Count -gt 0
}

function Test-UeefSensitiveRelativePath {
  param([Parameter(Mandatory)][string]$RelativePath)
  $name = [IO.Path]::GetFileName($RelativePath).ToLowerInvariant()
  return $name -eq '.env' -or $name.StartsWith('.env.') -or
    $name -in @('credentials.json','service-account.json','id_rsa','id_ed25519') -or
    $name -like 'service-account-*.json' -or
    [IO.Path]::GetExtension($name) -in @('.pem','.key','.pfx','.p12')
}

function Test-UeefOwnedRelativePath {
  param([Parameter(Mandatory)][string]$RelativePath)
  $normalized = $RelativePath.Replace('\','/').TrimStart('/')
  if ($script:UeefOwnedRootFiles -ccontains $normalized) { return $true }
  $first = $normalized.Split('/')[0]
  return $script:UeefOwnedDirectories -ccontains $first
}

function Test-UeefIgnoredReleaseRelativePath {
  param([Parameter(Mandatory)][string]$RelativePath)
  $normalized = $RelativePath.Replace('\','/').TrimStart('/')
  $segments = $normalized.Split('/')
  return $normalized -like '*.tmp' -or $normalized -like '*.log' -or
    ($segments | Where-Object { $_ -in @('.ueef-local','node_modules','dist','build') }).Count -gt 0
}

function Assert-UeefReleasePathHasNoReparsePoint {
  param(
    [Parameter(Mandatory)][string]$RootPath,
    [Parameter(Mandatory)][string]$RelativePath
  )
  $current = $RootPath
  foreach ($segment in $RelativePath.Replace('\','/').Split('/', [StringSplitOptions]::RemoveEmptyEntries)) {
    $current = Join-Path $current $segment
    if (!(Test-Path -LiteralPath $current)) { throw "Tracked release file is missing: $RelativePath" }
    $item = Get-Item -LiteralPath $current -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "Reparse-point release path is not allowed: $RelativePath"
    }
  }
}

function Get-UeefReleaseRelativeFiles {
  param(
    [Parameter(Mandatory)][string]$SourcePath,
    [switch]$SkipPathSafetyValidation
  )
  $root = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourcePath).Path).TrimEnd('\','/')
  $relativeFiles = @()
  $git = Get-Command git -ErrorAction SilentlyContinue
  if ($git -and (Test-Path -LiteralPath (Join-Path $root '.git'))) {
    # Repository ownership can be stricter on Windows CI or shared drives.
    # Scope the safe-directory exception to this exact source path instead of
    # asking users to mutate global Git configuration.
    $relativeFiles = @(& $git.Source -c "safe.directory=$root" -C $root ls-files --recurse-submodules 2>$null)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to enumerate tracked release files.' }
  } else {
    foreach ($name in $script:UeefOwnedRootFiles) {
      if (Test-Path -LiteralPath (Join-Path $root $name) -PathType Leaf) { $relativeFiles += $name }
    }
    foreach ($directory in $script:UeefOwnedDirectories) {
      $ownedRoot = Join-Path $root $directory
      if (!(Test-Path -LiteralPath $ownedRoot -PathType Container)) { continue }
      $relativeFiles += Get-ChildItem -LiteralPath $ownedRoot -File -Recurse -Force | ForEach-Object {
        $_.FullName.Substring($root.Length).TrimStart('\','/').Replace('\','/')
      }
    }
  }

  $result = [System.Collections.Generic.List[string]]::new()
  foreach ($relative in $relativeFiles | Sort-Object -Unique) {
    $normalized = ([string]$relative).Replace('\','/').TrimStart('/')
    if (!$normalized -or $normalized -eq 'UEEF-LOADER.md' -or !(Test-UeefOwnedRelativePath $normalized)) { continue }
    if (Test-UeefIgnoredReleaseRelativePath $normalized) { continue }
    if ($normalized.Split('/') -contains '..') { throw "Unsafe release path: $normalized" }
    if (Test-UeefSensitiveRelativePath $normalized) { throw "Sensitive file cannot enter the runtime: $normalized" }
    if (!$SkipPathSafetyValidation) { Assert-UeefReleasePathHasNoReparsePoint -RootPath $root -RelativePath $normalized }
    $full = Join-Path $root $normalized
    if (!(Test-Path -LiteralPath $full -PathType Leaf)) { throw "Tracked release file is missing: $normalized" }
    $result.Add($normalized)
  }
  return $result.ToArray()
}

function Get-UeefReleaseRelativeFilesFast {
  param([Parameter(Mandatory)][string]$SourcePath)
  $root = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourcePath).Path).TrimEnd('\','/')
  $git = Get-Command git -ErrorAction SilentlyContinue
  if (!$git -or !(Test-Path -LiteralPath (Join-Path $root '.git'))) {
    return @(Get-UeefReleaseRelativeFiles -SourcePath $root -SkipPathSafetyValidation)
  }
  $pathspec = @($script:UeefOwnedDirectories) + @($script:UeefOwnedRootFiles)
  $relativeFiles = @(& $git.Source -c "safe.directory=$root" -C $root ls-files --recurse-submodules -- @pathspec 2>$null)
  if ($LASTEXITCODE -ne 0) { throw 'Unable to enumerate tracked release files.' }
  $ignoredPattern = '(?:^|/)(?:\.ueef-local|node_modules|dist|build)(?:/|$)|(?:\.tmp|\.log)$'
  $sensitivePattern = '(?i)(?:^|/)(?:\.env(?:\..+)?|credentials\.json|service-account(?:-.+)?\.json|id_rsa|id_ed25519|[^/]+\.(?:pem|key|pfx|p12))$'
  return @($relativeFiles | ForEach-Object { ([string]$_).Replace('\','/').TrimStart('/') } | Where-Object {
    $_ -and $_ -ne 'UEEF-LOADER.md' -and $_ -notmatch $ignoredPattern -and $_ -notmatch $sensitivePattern -and $_ -notmatch '(?:^|/)\.\.(?:/|$)'
  } | Sort-Object -Unique)
}

function Get-UeefContentHashes {
  param(
    [Parameter(Mandatory)][string]$RootPath,
    [Parameter(Mandatory)][string[]]$RelativePaths
  )
  if (!$RelativePaths.Count) { return @() }
  $git = Get-Command git -ErrorAction SilentlyContinue
  if ($git) {
    try {
      $psi = [Diagnostics.ProcessStartInfo]::new()
      $psi.FileName = $git.Source
      $psi.UseShellExecute = $false
      $psi.RedirectStandardInput = $true
      $psi.RedirectStandardOutput = $true
      $psi.RedirectStandardError = $true
      [void]$psi.ArgumentList.Add('-C')
      [void]$psi.ArgumentList.Add($RootPath)
      [void]$psi.ArgumentList.Add('hash-object')
      [void]$psi.ArgumentList.Add('--stdin-paths')
      $process = [Diagnostics.Process]::Start($psi)
      foreach ($relative in $RelativePaths) { $process.StandardInput.WriteLine($relative) }
      $process.StandardInput.Close()
      $stdout = $process.StandardOutput.ReadToEnd()
      $process.StandardError.ReadToEnd() | Out-Null
      $process.WaitForExit()
      $hashes = @($stdout -split "`r?`n" | Where-Object { $_ })
      if ($process.ExitCode -eq 0 -and $hashes.Count -eq $RelativePaths.Count) { return $hashes }
    } catch {}
  }
  return @($RelativePaths | ForEach-Object { (Get-FileHash -LiteralPath (Join-Path $RootPath $_) -Algorithm SHA256).Hash })
}

function Get-UeefRuntimeDriftMismatches {
  param(
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][string]$RuntimePath,
    [string]$ExpectedLoaderHash = ''
  )
  $sourceRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourcePath).Path).TrimEnd('\','/')
  $runtimeRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $RuntimePath).Path).TrimEnd('\','/')
  $sourceFiles = @(Get-UeefReleaseRelativeFilesFast -SourcePath $sourceRoot)
  $sourceSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($relative in $sourceFiles) { [void]$sourceSet.Add($relative) }
  $mismatches = [Collections.Generic.List[string]]::new()
  $comparable = @($sourceFiles | Where-Object {
    if (Test-Path -LiteralPath (Join-Path $runtimeRoot $_) -PathType Leaf) { $true } else { $mismatches.Add("Missing runtime: $_"); $false }
  })
  $sourceHashes = @(Get-UeefContentHashes -RootPath $sourceRoot -RelativePaths $comparable)
  $runtimeHashes = @(Get-UeefContentHashes -RootPath $runtimeRoot -RelativePaths $comparable)
  for ($index = 0; $index -lt $comparable.Count; $index++) {
    if ($sourceHashes[$index] -cne $runtimeHashes[$index]) { $mismatches.Add("Different: $($comparable[$index])") }
  }
  foreach ($runtimeItem in Get-ChildItem -LiteralPath $runtimeRoot -Recurse -Force) {
    $relative = $runtimeItem.FullName.Substring($runtimeRoot.Length).TrimStart('\','/').Replace('\','/')
    if (($runtimeItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      $mismatches.Add("Unsafe runtime reparse point: $relative")
      continue
    }
    if (Test-UeefRuntimeGeneratedRelativePath $relative) { continue }
    if (!$runtimeItem.PSIsContainer -and $relative -ne 'UEEF-LOADER.md' -and !$sourceSet.Contains($relative)) {
      $mismatches.Add("Extra runtime: $relative")
    }
  }
  $runtimeLoader = Join-Path $runtimeRoot 'UEEF-LOADER.md'
  if (!(Test-Path -LiteralPath $runtimeLoader -PathType Leaf)) {
    $mismatches.Add('Missing runtime: UEEF-LOADER.md')
  } else {
    $loaderText = Get-Content -LiteralPath $runtimeLoader -Raw
    foreach ($term in @('Agent and model routing:','environment-bootstrap','Loaded: boot-loader, core-system')) {
      if ($loaderText -notmatch [regex]::Escape($term)) { $mismatches.Add("Runtime loader missing contract: $term") }
    }
    if (![string]::IsNullOrWhiteSpace($ExpectedLoaderHash)) {
      $actualLoaderHash = (Get-FileHash -LiteralPath $runtimeLoader -Algorithm SHA256).Hash
      if ($actualLoaderHash -cne $ExpectedLoaderHash.ToUpperInvariant()) { $mismatches.Add('Different: UEEF-LOADER.md') }
    }
  }
  return $mismatches.ToArray()
}

function Get-UeefRuntimeContentSignature {
  param(
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][string]$RuntimePath,
    [string]$ExpectedLoaderHash = ''
  )
  $sourceRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourcePath).Path).TrimEnd('\','/')
  $runtimeRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $RuntimePath).Path).TrimEnd('\','/')
  $records = [Collections.Generic.List[string]]::new()
  $releaseFiles = @(Get-UeefReleaseRelativeFilesFast -SourcePath $sourceRoot)
  $runtimeItems = @(Get-ChildItem -LiteralPath $runtimeRoot -Recurse -Force)
  $runtimeByRelativePath = @{}
  foreach ($runtimeItem in $runtimeItems) {
    $relative = $runtimeItem.FullName.Substring($runtimeRoot.Length).TrimStart('\','/').Replace('\','/')
    $runtimeByRelativePath[$relative] = $runtimeItem
  }
  $comparable = @($releaseFiles | Where-Object { $runtimeByRelativePath.ContainsKey($_) -and !$runtimeByRelativePath[$_].PSIsContainer })
  $sourceHashes = @(Get-UeefContentHashes -RootPath $sourceRoot -RelativePaths $comparable)
  $runtimeHashes = @(Get-UeefContentHashes -RootPath $runtimeRoot -RelativePaths $comparable)
  $hashByRelative = @{}
  for ($index = 0; $index -lt $comparable.Count; $index++) { $hashByRelative[$comparable[$index]] = "$($sourceHashes[$index])|$($runtimeHashes[$index])" }
  foreach ($relative in $releaseFiles) { $records.Add("F|$relative|$(if ($hashByRelative.ContainsKey($relative)) { $hashByRelative[$relative] } else { 'MISSING' })") }
  foreach ($runtimeItem in $runtimeItems) {
    $relative = $runtimeItem.FullName.Substring($runtimeRoot.Length).TrimStart('\','/').Replace('\','/')
    if (Test-UeefRuntimeGeneratedRelativePath $relative) { continue }
    $kind = if ($runtimeItem.PSIsContainer) { 'D' } else { 'X' }
    $length = if ($runtimeItem.PSIsContainer) { 0 } else { $runtimeItem.Length }
    $reparse = if (($runtimeItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { 1 } else { 0 }
    $records.Add("$kind|$relative|$length|$($runtimeItem.LastWriteTimeUtc.Ticks)|$reparse")
  }
  $records.Add("L|$ExpectedLoaderHash")
  $runtimeLoader = Join-Path $runtimeRoot 'UEEF-LOADER.md'
  $records.Add("LA|$(if (Test-Path -LiteralPath $runtimeLoader -PathType Leaf) { (Get-FileHash -LiteralPath $runtimeLoader -Algorithm SHA256).Hash } else { 'MISSING' })")
  $payload = ($records | Sort-Object) -join "`n"
  $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','') } finally { $sha.Dispose() }
}

function Copy-UeefReleaseFiles {
  param(
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][string]$DestinationPath
  )
  $sourceRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourcePath).Path).TrimEnd('\','/')
  $destinationRoot = [IO.Path]::GetFullPath($DestinationPath).TrimEnd('\','/')
  if ($destinationRoot -eq [IO.Path]::GetPathRoot($destinationRoot) -or
      $destinationRoot.StartsWith($sourceRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
      $sourceRoot.StartsWith($destinationRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
      $destinationRoot -eq $sourceRoot) {
    throw "Refusing unsafe or overlapping release destination: $destinationRoot"
  }
  if (Test-Path -LiteralPath $destinationRoot) {
    $item = Get-Item -LiteralPath $destinationRoot -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Refusing reparse-point release destination: $destinationRoot" }
    if (Get-ChildItem -LiteralPath $destinationRoot -Force | Select-Object -First 1) { throw "Release destination must be empty: $destinationRoot" }
  } else { New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null }
  foreach ($relative in Get-UeefReleaseRelativeFiles -SourcePath $sourceRoot) {
    $source = Join-Path $sourceRoot $relative
    $destination = Join-Path $destinationRoot $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
  }
}
