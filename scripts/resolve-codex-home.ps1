# Resolves the Codex home directory for this machine.
# Preference: explicit Override -> CODEX_HOME env -> available machine default -> standard user home.
function Resolve-CodexHome {
  param([string]$Override = '')
  if (![string]::IsNullOrWhiteSpace($Override)) { return $Override.TrimEnd('\', '/') }
  if (![string]::IsNullOrWhiteSpace($env:CODEX_HOME)) { return $env:CODEX_HOME.TrimEnd('\', '/') }
  $machineDefault = 'E:\shared folder\codex-home'
  if (Test-Path -LiteralPath $machineDefault -PathType Container) { return $machineDefault }
  return (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex')
}

function Resolve-UeefCodexRuntimePath {
  param(
    [string]$CodexHome = '',
    [string]$Agent = 'codex'
  )
  $resolvedHome = Resolve-CodexHome -Override $CodexHome
  return (Join-Path $resolvedHome (Join-Path 'ueef' $Agent))
}

function Resolve-UeefBackupRoot {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$CodexHome,
    [string]$BackupRoot = ''
  )

  $resolvedCodexHome = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $CodexHome -ErrorAction Stop).Path).TrimEnd('\','/')
  $candidate = $BackupRoot
  if ([string]::IsNullOrWhiteSpace($candidate)) { $candidate = $env:UEEF_BACKUP_ROOT }

  if ([string]::IsNullOrWhiteSpace($candidate)) {
    $configuredCodexHome = if ($env:CODEX_HOME) {
      [IO.Path]::GetFullPath($env:CODEX_HOME).TrimEnd('\','/')
    } else {
      ''
    }

    if ($env:LOCALAPPDATA -and $configuredCodexHome -and $resolvedCodexHome.Equals($configuredCodexHome, [StringComparison]::OrdinalIgnoreCase)) {
      $candidate = Join-Path $env:LOCALAPPDATA 'Codex-Recovery\UEEF-backups'
    } else {
      $parent = Split-Path -Parent $resolvedCodexHome
      $leaf = Split-Path -Leaf $resolvedCodexHome
      $candidate = Join-Path $parent ($leaf + '-recovery\UEEF-backups')
    }
  }

  $resolvedBackupRoot = [IO.Path]::GetFullPath($candidate).TrimEnd('\','/')
  $codexPrefix = $resolvedCodexHome + [IO.Path]::DirectorySeparatorChar
  if ($resolvedBackupRoot.Equals($resolvedCodexHome, [StringComparison]::OrdinalIgnoreCase) -or
      $resolvedBackupRoot.StartsWith($codexPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "UEEF backup root must be outside CODEX_HOME: $resolvedBackupRoot"
  }

  $existingBackupRoot = Get-Item -LiteralPath $resolvedBackupRoot -Force -ErrorAction SilentlyContinue
  if ($existingBackupRoot -and (($existingBackupRoot.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
    throw "Refusing reparse-point UEEF backup root: $resolvedBackupRoot"
  }

  return $resolvedBackupRoot
}
