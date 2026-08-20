[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9-]{0,79}$')][string]$TaskId,
  [Parameter(Mandatory)][string[]]$SourcePath,
  [string]$RepositoryRoot = '.',
  [string]$OutputRoot = '',
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$ephemeralRoot = [IO.Path]::GetFullPath((Join-Path $root '.ueef'))
if ([string]::IsNullOrWhiteSpace($OutputRoot)) { $OutputRoot = Join-Path $root "docs\evidence\$TaskId" }
$destinationRoot = [IO.Path]::GetFullPath($OutputRoot)
$durableRoot = [IO.Path]::GetFullPath((Join-Path $root 'docs\evidence'))
$expectedDestinationRoot = [IO.Path]::GetFullPath((Join-Path $durableRoot $TaskId))
if (!$destinationRoot.StartsWith($durableRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Promoted evidence must be stored under docs/evidence/<task-id>.'
}
if ($destinationRoot -ne $expectedDestinationRoot) { throw 'OutputRoot must exactly match docs/evidence/<task-id>.' }
if ((Test-Path -LiteralPath $destinationRoot) -and !$Force) { throw "Promotion target already exists: $destinationRoot" }

function Assert-NoReparseTraversal([string]$Boundary, [string]$Candidate, [string]$Label) {
  $normalizedBoundary = [IO.Path]::GetFullPath($Boundary).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  $normalizedCandidate = [IO.Path]::GetFullPath($Candidate)
  $normalizedRepositoryRoot = [IO.Path]::GetFullPath($root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  if (!$normalizedCandidate.StartsWith($normalizedBoundary + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "$Label is outside its allowed root." }
  if ($normalizedBoundary -ne $normalizedRepositoryRoot -and !$normalizedBoundary.StartsWith($normalizedRepositoryRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "$Label boundary is outside the repository root."
  }
  $boundaryRelative = $normalizedBoundary.Substring($normalizedRepositoryRoot.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  $boundaryCursor = $normalizedRepositoryRoot
  foreach ($segment in @($boundaryRelative -split '[\\/]' | Where-Object { $_ -and $_ -ne '.' })) {
    $boundaryCursor = Join-Path $boundaryCursor $segment
    if (Test-Path -LiteralPath $boundaryCursor) {
      $boundaryItem = Get-Item -LiteralPath $boundaryCursor -Force
      if (($boundaryItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "$Label boundary traverses a reparse point: $boundaryCursor" }
    }
  }
  $relative = $normalizedCandidate.Substring($normalizedBoundary.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  $cursor = $normalizedBoundary
  foreach ($segment in @($relative -split '[\\/]' | Where-Object { $_ -and $_ -ne '.' })) {
    $cursor = Join-Path $cursor $segment
    if (Test-Path -LiteralPath $cursor) {
      $item = Get-Item -LiteralPath $cursor -Force
      if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "$Label traverses a reparse point: $cursor" }
    }
  }
}

function Assert-SingleLinkFile([string]$Path, [string]$Label) {
  if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { return }
  $node = Get-Command node -ErrorAction Stop
  $linkCount = & $node.Source -e "const fs=require('fs');process.stdout.write(String(fs.lstatSync(process.argv[1],{bigint:true}).nlink))" $Path
  if ($LASTEXITCODE -ne 0 -or [string]$linkCount -notmatch '^\d+$') { throw "$Label hard-link check failed: $Path" }
  if ([int64]$linkCount -ne 1) { throw "$Label must not be a hard link: $Path" }
}

Assert-NoReparseTraversal -Boundary $durableRoot -Candidate $destinationRoot -Label 'Evidence destination'

$records = foreach ($inputPath in $SourcePath) {
  $lexicalSource = [IO.Path]::GetFullPath($inputPath)
  Assert-NoReparseTraversal -Boundary $ephemeralRoot -Candidate $lexicalSource -Label 'Evidence source'
  $source = (Resolve-Path -LiteralPath $lexicalSource -ErrorAction Stop).Path
  if (!$source.StartsWith($ephemeralRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or !(Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "Evidence source must be a file below .ueef: $inputPath"
  }
  Assert-SingleLinkFile -Path $source -Label 'Evidence source'
  [pscustomobject]@{ source=$source; name=[IO.Path]::GetFileName($source); sha256=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() }
}
if (@($records).Count -ne @($records.name | Select-Object -Unique).Count) { throw 'Promoted evidence file names must be unique.' }
if (@($records.name | Where-Object { $_ -ieq 'manifest.json' }).Count) { throw 'manifest.json is reserved for the promotion manifest.' }

if ($PSCmdlet.ShouldProcess($destinationRoot, "Promote $(@($records).Count) UEEF evidence file(s)")) {
  New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null
  foreach ($record in $records) {
    $destination = Join-Path $destinationRoot $record.name
    Assert-NoReparseTraversal -Boundary $durableRoot -Candidate $destination -Label 'Evidence destination file'
    Assert-SingleLinkFile -Path $destination -Label 'Existing evidence destination'
    Copy-Item -LiteralPath $record.source -Destination $destination -Force:$Force
    if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant() -ne $record.sha256) { throw "Promoted evidence hash verification failed: $($record.name)" }
  }
  $manifest = [ordered]@{
    schemaVersion=1
    taskId=$TaskId
    promotedAt=(Get-Date).ToUniversalTime().ToString('o')
    sourceClass='ephemeral-.ueef'
    destinationClass='clone-durable-docs-evidence'
    files=@($records | ForEach-Object { [ordered]@{path=$_.name;sha256=$_.sha256} })
  }
  $manifestPath = Join-Path $destinationRoot 'manifest.json'
  Assert-NoReparseTraversal -Boundary $durableRoot -Candidate $manifestPath -Label 'Promotion manifest'
  Assert-SingleLinkFile -Path $manifestPath -Label 'Existing promotion manifest'
  if (Test-Path -LiteralPath $manifestPath -PathType Leaf) { Remove-Item -LiteralPath $manifestPath -Force }
  [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
  Write-Output $destinationRoot
}
