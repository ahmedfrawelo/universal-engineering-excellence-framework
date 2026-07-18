$script:UeefOwnedDirectories = @('framework','scripts','docs','examples','tools','assets')
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
  if ($normalized -in $script:UeefOwnedRootFiles) { return $true }
  $first = $normalized.Split('/')[0]
  return $first -in $script:UeefOwnedDirectories
}

function Get-UeefReleaseRelativeFiles {
  param([Parameter(Mandatory)][string]$SourcePath)
  $root = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourcePath).Path).TrimEnd('\','/')
  $relativeFiles = @()
  $git = Get-Command git -ErrorAction SilentlyContinue
  if ($git -and (Test-Path -LiteralPath (Join-Path $root '.git'))) {
    $relativeFiles = @(& $git.Source -C $root ls-files --recurse-submodules 2>$null)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to enumerate tracked release files.' }
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
    $full = Join-Path $root $normalized
    if (!(Test-Path -LiteralPath $full -PathType Leaf)) { throw "Tracked release file is missing: $normalized" }
    $item = Get-Item -LiteralPath $full -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Reparse-point release file is not allowed: $normalized" }
    $result.Add($normalized)
  }
  return $result.ToArray()
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
