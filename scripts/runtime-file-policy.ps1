$script:UeefOwnedDirectories = @('framework','scripts','docs','examples','tools','assets','config')
$script:UeefOwnedRootFiles = @(
  '.gitattributes','.gitignore','BUILD_PROGRESS.md','CHANGELOG.md','CODE_OF_CONDUCT.md',
  'CONTRIBUTING.md','INSTALL.md','LICENSE','QUICK_START.md','README.md','ROADMAP.md',
  'SECURITY.md','VERSION.md','release-manifest.json'
)

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
  param([Parameter(Mandatory)][string]$SourcePath)
  $root = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourcePath).Path).TrimEnd('\','/')
  $relativeFiles = @()
  $git = Get-Command git -ErrorAction SilentlyContinue
  if ($git -and (Test-Path -LiteralPath (Join-Path $root '.git'))) {
    $relativeFiles = @(& $git.Source -C $root ls-files --recurse-submodules 2>$null)
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
    if ($normalized.Split('/') -contains '..') { throw "Unsafe release path: $normalized" }
    if (Test-UeefSensitiveRelativePath $normalized) { throw "Sensitive file cannot enter the runtime: $normalized" }
    Assert-UeefReleasePathHasNoReparsePoint -RootPath $root -RelativePath $normalized
    $full = Join-Path $root $normalized
    if (!(Test-Path -LiteralPath $full -PathType Leaf)) { throw "Tracked release file is missing: $normalized" }
    $result.Add($normalized)
  }
  return $result.ToArray()
}

function Get-UeefRuntimeDriftMismatches {
  param(
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][string]$RuntimePath,
    [string]$ExpectedLoaderHash = ''
  )
  $sourceRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourcePath).Path).TrimEnd('\','/')
  $runtimeRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $RuntimePath).Path).TrimEnd('\','/')
  $sourceFiles = @(Get-UeefReleaseRelativeFiles -SourcePath $sourceRoot)
  $sourceSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($relative in $sourceFiles) { [void]$sourceSet.Add($relative) }
  $mismatches = [Collections.Generic.List[string]]::new()
  foreach ($relative in $sourceFiles) {
    $sourceFile = Join-Path $sourceRoot $relative
    $runtimeFile = Join-Path $runtimeRoot $relative
    if (!(Test-Path -LiteralPath $runtimeFile -PathType Leaf)) { $mismatches.Add("Missing runtime: $relative"); continue }
    if ((Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $runtimeFile -Algorithm SHA256).Hash) {
      $mismatches.Add("Different: $relative")
    }
  }
  foreach ($runtimeItem in Get-ChildItem -LiteralPath $runtimeRoot -Recurse -Force) {
    $relative = $runtimeItem.FullName.Substring($runtimeRoot.Length).TrimStart('\','/').Replace('\','/')
    if (($runtimeItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      $mismatches.Add("Unsafe runtime reparse point: $relative")
      continue
    }
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
