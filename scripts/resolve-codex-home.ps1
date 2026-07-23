# Resolves the Codex home directory for this machine.
# Preference: explicit Override -> CODEX_HOME env -> E:\shared folder\codex-home
function Resolve-CodexHome {
  param([string]$Override = '')
  if (![string]::IsNullOrWhiteSpace($Override)) { return $Override.TrimEnd('\', '/') }
  if (![string]::IsNullOrWhiteSpace($env:CODEX_HOME)) { return $env:CODEX_HOME.TrimEnd('\', '/') }
  return 'E:\shared folder\codex-home'
}

function Resolve-UeefCodexRuntimePath {
  param(
    [string]$CodexHome = '',
    [string]$Agent = 'codex'
  )
  $home = Resolve-CodexHome -Override $CodexHome
  return (Join-Path $home (Join-Path 'ueef' $Agent))
}
