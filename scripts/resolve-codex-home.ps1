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
