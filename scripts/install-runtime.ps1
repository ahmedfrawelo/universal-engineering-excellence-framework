param(
  [Parameter(Mandatory)][string]$SourceRoot,
  [Parameter(Mandatory)][string]$InstallRoot,
  [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')][string]$Agent,
  [switch]$Force,
  [switch]$NoBackup,
  [switch]$TestFailAfterState
)
$ErrorActionPreference = 'Stop'
if ($Agent -in @('.','..')) { throw 'Unsafe agent name.' }
if ($NoBackup -and !$Force) { throw '-NoBackup requires -Force.' }
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path).TrimEnd('\','/')
New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
$install = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InstallRoot).Path).TrimEnd('\','/')
$installItem = Get-Item -LiteralPath $InstallRoot -Force
if (($installItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Refusing reparse-point install root: $InstallRoot" }
$target = [IO.Path]::GetFullPath((Join-Path $install $Agent)).TrimEnd('\','/')
if ((Split-Path -Parent $target) -ne $install) { throw "Refusing unsafe runtime target: $target" }
if ($source -eq $target) { Write-Host "UEEF is already running from $target; install is a no-op."; return }
if ($target.StartsWith($source + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
    $source.StartsWith($target + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
  throw "Refusing overlapping source and target paths: $source -> $target"
}
if ((Test-Path -LiteralPath $target) -and ((Get-Item -LiteralPath $target -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
  throw "Refusing reparse-point runtime target: $target"
}
& (Join-Path $source 'scripts\validate-framework.ps1') -Root $source -SkipNestedTests | Out-Null
$stage = Join-Path $install ('.s' + [guid]::NewGuid().ToString('N').Substring(0,8))
$rollback = Join-Path $install ('.r' + [guid]::NewGuid().ToString('N').Substring(0,8))
$swapped = $false
$statePath = Join-Path $install 'UEEF-ACTIVE.json'
$stateItem = Get-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue
if ($stateItem -and (($stateItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw "Refusing reparse-point active state: $statePath" }
$stateExisted = Test-Path -LiteralPath $statePath -PathType Leaf
$stateBackup = $null
if ($stateExisted) {
  $stateBackup = Join-Path $install ('.state-' + [guid]::NewGuid().ToString('N') + '.json')
  Copy-Item -LiteralPath $statePath -Destination $stateBackup -Force
}
try {
  & node (Join-Path $source 'scripts\copy-release-files.mjs') $source $stage --include-loader | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Release copy failed.' }
  & (Join-Path $stage 'scripts\validate-framework.ps1') -Root $stage -SkipNestedTests | Out-Null
  if (Test-Path -LiteralPath $target) {
    if (!$Force) { throw "Existing UEEF install found at $target. Re-run with -Force to replace it." }
    if (!$NoBackup) {
      $backup = Join-Path $install ('backups\{0}-{1}-{2}' -f $Agent, (Get-Date -Format yyyyMMddHHmmssfff), [guid]::NewGuid().ToString('N'))
      New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force | Out-Null
      Copy-Item -LiteralPath $target -Destination $backup -Recurse -Force
    }
    Move-Item -LiteralPath $target -Destination $rollback
  }
  Move-Item -LiteralPath $stage -Destination $target
  $swapped = $true
  & (Join-Path $target 'scripts\write-active-state.ps1') -RepositoryPath $target -CodexHome (Split-Path -Parent $install) -RuntimeRoot $install -Agent $Agent -SourceRepositoryPath $source | Out-Null
  if ($TestFailAfterState) { throw 'Injected test failure after active-state write.' }
  if (Test-Path -LiteralPath $rollback) { Remove-Item -LiteralPath $rollback -Recurse -Force }
  $swapped = $false
  if ($stateBackup -and (Test-Path -LiteralPath $stateBackup)) { Remove-Item -LiteralPath $stateBackup -Force -ErrorAction SilentlyContinue }
  Write-Host "UEEF installed for $Agent at $target"
  Write-Host "Verify loader: $(Join-Path $target 'UEEF-LOADER.md')"
} catch {
  $failure = $_
  if ($swapped -and (Test-Path -LiteralPath $target)) { Remove-Item -LiteralPath $target -Recurse -Force }
  if (Test-Path -LiteralPath $rollback) { Move-Item -LiteralPath $rollback -Destination $target }
  if ($stateExisted -and $stateBackup -and (Test-Path -LiteralPath $stateBackup)) {
    Copy-Item -LiteralPath $stateBackup -Destination $statePath -Force
  } elseif (!$stateExisted -and (Test-Path -LiteralPath $statePath)) {
    Remove-Item -LiteralPath $statePath -Force
  }
  Get-ChildItem -LiteralPath $install -Filter 'UEEF-ACTIVE.json.tmp.*' -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
  if ($stateBackup -and (Test-Path -LiteralPath $stateBackup)) { Remove-Item -LiteralPath $stateBackup -Force -ErrorAction SilentlyContinue }
  if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
  throw $failure
}
