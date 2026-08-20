$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sandbox = Join-Path ([IO.Path]::GetTempPath()) "ueef-evidence-promotion-$([guid]::NewGuid().ToString('N'))"
try {
  New-Item -ItemType Directory -Path (Join-Path $sandbox '.ueef\evidence'), (Join-Path $sandbox 'docs') -Force | Out-Null
  $source = Join-Path $sandbox '.ueef\evidence\task.json'
  [IO.File]::WriteAllText($source, '{"status":"PASS"}', [Text.UTF8Encoding]::new($false))
  $output = & (Join-Path $root 'scripts\promote-ueef-evidence.ps1') -TaskId 'promotion-test' -SourcePath $source -RepositoryRoot $sandbox
  $manifestPath = Join-Path $output 'manifest.json'
  $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  if ($manifest.taskId -ne 'promotion-test' -or $manifest.destinationClass -ne 'clone-durable-docs-evidence' -or @($manifest.files).Count -ne 1) { throw 'Evidence promotion manifest is invalid.' }
  if ((Get-FileHash -LiteralPath (Join-Path $output 'task.json') -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.files[0].sha256) { throw 'Promoted evidence hash does not match its manifest.' }
  $outsideRejected = $false
  try { & (Join-Path $root 'scripts\promote-ueef-evidence.ps1') -TaskId 'outside-test' -SourcePath (Join-Path $root 'VERSION.md') -RepositoryRoot $sandbox | Out-Null }
  catch { $outsideRejected = $_.Exception.Message -like '*outside its allowed root*' -or $_.Exception.Message -like '*below .ueef*' }
  if (!$outsideRejected) { throw 'Evidence promotion accepted a source outside .ueef.' }
  $mismatchedOutputRejected = $false
  try { & (Join-Path $root 'scripts\promote-ueef-evidence.ps1') -TaskId 'task-a' -SourcePath $source -RepositoryRoot $sandbox -OutputRoot (Join-Path $sandbox 'docs\evidence\task-b') | Out-Null }
  catch { $mismatchedOutputRejected = $_.Exception.Message -like '*exactly match*' }
  if (!$mismatchedOutputRejected) { throw 'Evidence promotion accepted an OutputRoot that disagrees with TaskId.' }
  $reservedManifest = Join-Path $sandbox '.ueef\evidence\manifest.json'
  Set-Content -LiteralPath $reservedManifest -Value '{"status":"source"}' -Encoding utf8
  $reservedManifestRejected = $false
  try { & (Join-Path $root 'scripts\promote-ueef-evidence.ps1') -TaskId 'manifest-collision' -SourcePath $reservedManifest -RepositoryRoot $sandbox | Out-Null }
  catch { $reservedManifestRejected = $_.Exception.Message -like '*reserved*' }
  if (!$reservedManifestRejected) { throw 'Evidence promotion accepted a source named manifest.json.' }
  $outsideHardLinkTarget = Join-Path $sandbox 'outside-hardlink.json'
  Set-Content -LiteralPath $outsideHardLinkTarget -Value '{"private":"outside"}' -Encoding utf8
  $sourceHardLink = Join-Path $sandbox '.ueef\evidence\source-hardlink.json'
  New-Item -ItemType HardLink -Path $sourceHardLink -Target $outsideHardLinkTarget | Out-Null
  $sourceHardLinkRejected = $false
  try { & (Join-Path $root 'scripts\promote-ueef-evidence.ps1') -TaskId 'source-hardlink' -SourcePath $sourceHardLink -RepositoryRoot $sandbox | Out-Null }
  catch { $sourceHardLinkRejected = $_.Exception.Message -like '*hard link*' }
  if (!$sourceHardLinkRejected) { throw 'Evidence promotion accepted a hard-linked source.' }

  $hardLinkDestinationRoot = Join-Path $sandbox 'docs\evidence\destination-hardlink'
  New-Item -ItemType Directory -Path $hardLinkDestinationRoot -Force | Out-Null
  $outsideVictim = Join-Path $sandbox 'outside-victim.json'
  Set-Content -LiteralPath $outsideVictim -Value '{"preserve":true}' -Encoding utf8
  New-Item -ItemType HardLink -Path (Join-Path $hardLinkDestinationRoot 'task.json') -Target $outsideVictim | Out-Null
  $destinationHardLinkRejected = $false
  try { & (Join-Path $root 'scripts\promote-ueef-evidence.ps1') -TaskId 'destination-hardlink' -SourcePath $source -RepositoryRoot $sandbox -Force | Out-Null }
  catch { $destinationHardLinkRejected = $_.Exception.Message -like '*hard link*' }
  if (!$destinationHardLinkRejected -or (Get-Content -LiteralPath $outsideVictim -Raw) -notlike '*preserve*') { throw 'Evidence promotion followed an existing destination hard link.' }
  $manifestHardLinkRoot = Join-Path $sandbox 'docs\evidence\manifest-hardlink'
  New-Item -ItemType Directory -Path $manifestHardLinkRoot -Force | Out-Null
  $outsideManifestVictim = Join-Path $sandbox 'outside-manifest-victim.json'
  Set-Content -LiteralPath $outsideManifestVictim -Value '{"preserve":"manifest"}' -Encoding utf8
  New-Item -ItemType HardLink -Path (Join-Path $manifestHardLinkRoot 'manifest.json') -Target $outsideManifestVictim | Out-Null
  $manifestHardLinkRejected = $false
  try { & (Join-Path $root 'scripts\promote-ueef-evidence.ps1') -TaskId 'manifest-hardlink' -SourcePath $source -RepositoryRoot $sandbox -Force | Out-Null }
  catch { $manifestHardLinkRejected = $_.Exception.Message -like '*hard link*' }
  if (!$manifestHardLinkRejected -or (Get-Content -LiteralPath $outsideManifestVictim -Raw) -notlike '*preserve*') { throw 'Evidence promotion followed an existing manifest hard link.' }
  $symlinkDestinationRoot = Join-Path $sandbox 'docs\evidence\destination-symlink'
  New-Item -ItemType Directory -Path $symlinkDestinationRoot -Force | Out-Null
  $outsideSymlinkVictim = Join-Path $sandbox 'outside-symlink-victim.json'
  Set-Content -LiteralPath $outsideSymlinkVictim -Value '{"preserve":"symlink"}' -Encoding utf8
  $destinationSymlink = Join-Path $symlinkDestinationRoot 'task.json'
  try { New-Item -ItemType SymbolicLink -Path $destinationSymlink -Target $outsideSymlinkVictim -ErrorAction Stop | Out-Null } catch { $destinationSymlink = '' }
  if ($destinationSymlink) {
    $destinationSymlinkRejected = $false
    try { & (Join-Path $root 'scripts\promote-ueef-evidence.ps1') -TaskId 'destination-symlink' -SourcePath $source -RepositoryRoot $sandbox -Force | Out-Null }
    catch { $destinationSymlinkRejected = $_.Exception.Message -like '*reparse point*' }
    if (!$destinationSymlinkRejected -or (Get-Content -LiteralPath $outsideSymlinkVictim -Raw) -notlike '*preserve*') { throw 'Evidence promotion followed an existing destination symlink.' }
  }
  $external = Join-Path $sandbox 'external'
  New-Item -ItemType Directory -Path $external -Force | Out-Null
  $externalFile = Join-Path $external 'external.json'
  Set-Content -LiteralPath $externalFile -Value '{"private":true}' -Encoding utf8
  $junction = Join-Path $sandbox '.ueef\linked'
  cmd /c mklink /J "`"$junction`"" "`"$external`"" | Out-Null
  if (Test-Path -LiteralPath $junction) {
    $junctionRejected = $false
    try { & (Join-Path $root 'scripts\promote-ueef-evidence.ps1') -TaskId 'junction-test' -SourcePath (Join-Path $junction 'external.json') -RepositoryRoot $sandbox | Out-Null }
    catch { $junctionRejected = $_.Exception.Message -like '*reparse point*' }
    if (!$junctionRejected) { throw 'Evidence promotion accepted a source through a junction.' }
  }
  $externalDestination = Join-Path $sandbox 'external-destination'
  New-Item -ItemType Directory -Path $externalDestination -Force | Out-Null
  $durableRoot = Join-Path $sandbox 'docs\evidence'
  New-Item -ItemType Directory -Path $durableRoot -Force | Out-Null
  $destinationJunction = Join-Path $durableRoot 'destination-junction-test'
  cmd /c mklink /J "`"$destinationJunction`"" "`"$externalDestination`"" | Out-Null
  if (Test-Path -LiteralPath $destinationJunction) {
    $destinationJunctionRejected = $false
    try { & (Join-Path $root 'scripts\promote-ueef-evidence.ps1') -TaskId 'destination-junction-test' -SourcePath $source -RepositoryRoot $sandbox -Force | Out-Null }
    catch { $destinationJunctionRejected = $_.Exception.Message -like '*reparse point*' }
    if (!$destinationJunctionRejected) { throw 'Evidence promotion accepted a destination junction.' }
  }
  $boundarySandbox = Join-Path ([IO.Path]::GetTempPath()) "ueef-evidence-boundary-$([guid]::NewGuid().ToString('N'))"
  try {
    $externalEphemeral = Join-Path $boundarySandbox 'external-ephemeral'
    $externalDurable = Join-Path $boundarySandbox 'external-durable'
    $boundaryRepository = Join-Path $boundarySandbox 'repository'
    New-Item -ItemType Directory -Path $externalEphemeral,$externalDurable,(Join-Path $boundaryRepository 'docs') -Force | Out-Null
    $externalEvidence = Join-Path $externalEphemeral 'secret.json'
    Set-Content -LiteralPath $externalEvidence -Value '{"private":true}' -Encoding utf8
    $ephemeralBoundary = Join-Path $boundaryRepository '.ueef'
    cmd /c mklink /J "`"$ephemeralBoundary`"" "`"$externalEphemeral`"" | Out-Null
    $ephemeralBoundaryRejected = $false
    try { & (Join-Path $root 'scripts\promote-ueef-evidence.ps1') -TaskId 'ephemeral-boundary' -SourcePath (Join-Path $ephemeralBoundary 'secret.json') -RepositoryRoot $boundaryRepository | Out-Null }
    catch { $ephemeralBoundaryRejected = $_.Exception.Message -like '*boundary*reparse point*' }
    if (!$ephemeralBoundaryRejected) { throw 'Evidence promotion accepted a reparse-point .ueef boundary.' }
    [IO.Directory]::Delete($ephemeralBoundary)

    $localEphemeral = Join-Path $boundaryRepository '.ueef\evidence'
    New-Item -ItemType Directory -Path $localEphemeral -Force | Out-Null
    $localEvidence = Join-Path $localEphemeral 'task.json'
    Set-Content -LiteralPath $localEvidence -Value '{"status":"PASS"}' -Encoding utf8
    $durableBoundary = Join-Path $boundaryRepository 'docs\evidence'
    cmd /c mklink /J "`"$durableBoundary`"" "`"$externalDurable`"" | Out-Null
    $durableBoundaryRejected = $false
    try { & (Join-Path $root 'scripts\promote-ueef-evidence.ps1') -TaskId 'durable-boundary' -SourcePath $localEvidence -RepositoryRoot $boundaryRepository | Out-Null }
    catch { $durableBoundaryRejected = $_.Exception.Message -like '*boundary*reparse point*' }
    if (!$durableBoundaryRejected -or (Test-Path -LiteralPath (Join-Path $externalDurable 'durable-boundary'))) { throw 'Evidence promotion accepted a reparse-point docs/evidence boundary.' }
    [IO.Directory]::Delete($durableBoundary)
  } finally {
    if (Test-Path -LiteralPath $boundarySandbox) { Remove-Item -LiteralPath $boundarySandbox -Recurse -Force }
  }
  Write-Output 'Evidence promotion tests passed'
} finally {
  if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
