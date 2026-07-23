[CmdletBinding()]
param(
  [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }),
  [string]$ConfigPath,
  [string]$RegistryPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'config\capability-registry.json'),
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
if (!$ConfigPath) { $ConfigPath = Join-Path $CodexHome 'config.toml' }
$results = [Collections.Generic.List[object]]::new()
$registry = @{}
if (Test-Path -LiteralPath $RegistryPath -PathType Leaf) {
  $registryDocument = Get-Content -LiteralPath $RegistryPath -Raw | ConvertFrom-Json
  if ($registryDocument.schemaVersion -ne 1) { throw "Unsupported capability registry schema: $($registryDocument.schemaVersion)" }
  foreach ($entry in @($registryDocument.capabilities)) { $registry["$($entry.type)|$($entry.id)"] = $entry }
}

function Add-Capability([string]$Type, [string]$Name, [bool]$Configured, [bool]$Installed, [bool]$Enabled, [string]$Callable, [string]$Detail) {
  $declaration = $registry["$Type|$Name"]
  $health = if (!$Configured) { 'NOT_CONFIGURED' } elseif (!$Installed) { 'MISSING_DEPENDENCY' } elseif (!$Enabled) { 'DISABLED' } elseif ($Callable -eq 'PASS') { 'CALLABLE' } else { 'CONFIGURED_UNVERIFIED' }
  $results.Add([pscustomobject]@{ type=$Type; name=$Name; declared=[bool]$declaration; required=if($declaration){[bool]$declaration.required}else{$false}; configured=$Configured; installed=$Installed; enabled=$Enabled; callable=$Callable; health=$health; source=if($declaration){[string]$declaration.source}else{'observed configuration'}; versionOrPin=if($declaration){[string]$declaration.versionOrPin}else{''}; fallback=if($declaration){[string]$declaration.fallback}else{'No declared fallback.'}; consumerPacks=if($declaration){@($declaration.consumerPacks)}else{@()}; detail=$Detail })
}

# A SKILL.md proves local installation. It does not prove that a particular
# Codex session has selected the skill, so callable remains UNVERIFIED.
$skillRoot = Join-Path $CodexHome 'skills'
if (Test-Path -LiteralPath $skillRoot -PathType Container) {
  Get-ChildItem -LiteralPath $skillRoot -Recurse -Filter 'SKILL.md' -File | ForEach-Object {
    $relative = $_.FullName.Substring($skillRoot.Length).TrimStart('\','/')
    $name = ($relative -replace '[\\/]SKILL\.md$','' -replace '[\\/]','/')
    Add-Capability 'skill' $name $true $true $true 'UNVERIFIED' 'Local SKILL.md found; session selection is task-dependent.'
  }
}

if (Test-Path -LiteralPath $ConfigPath -PathType Leaf) {
  $lines = Get-Content -LiteralPath $ConfigPath
  $mcpNames = [Collections.Generic.List[string]]::new()
  $pluginStates = @{}
  foreach ($line in $lines) {
    if ($line -match '^\s*\[mcp_servers\.([^\.\]]+)\]\s*$') { if (!$mcpNames.Contains($matches[1])) { $mcpNames.Add($matches[1]) } }
    if ($line -match '^\s*\[plugins\."?([^"\]]+)"?\]\s*$') { $currentPlugin = $matches[1]; $pluginStates[$currentPlugin] = $false; continue }
    if ($currentPlugin -and $line -match '^\s*enabled\s*=\s*(true|false)\s*$') { $pluginStates[$currentPlugin] = ($matches[1] -eq 'true') }
    if ($line -match '^\s*\[') { $currentPlugin = $null }
  }
  foreach ($name in $mcpNames) {
    $section = $false; $command = ''; $url = ''
    foreach ($line in $lines) {
      if ($line -match '^\s*\[mcp_servers\.([^\.\]]+)\]\s*$') { $section = ($matches[1] -eq $name); continue }
      if ($section -and $line -match '^\s*\[') { break }
      if ($section -and $line -match '^\s*command\s*=\s*["'']([^"'']+)["'']') { $command=$matches[1] }
      if ($section -and $line -match '^\s*url\s*=\s*["'']([^"'']+)["'']') { $url=$matches[1] }
    }
    $installed = if ($command) { if ([IO.Path]::IsPathRooted($command)) { Test-Path -LiteralPath $command -PathType Leaf } else { [bool](Get-Command $command -ErrorAction SilentlyContinue) } } elseif ($url) { $true } else { $false }
    $detail = if ($command) { 'Local command configured; no process was started by this diagnostic.' } elseif ($url) { 'Remote endpoint configured; no network request was made by this diagnostic.' } else { 'Configuration has neither command nor URL.' }
    Add-Capability 'mcp' $name $true $installed $true 'UNVERIFIED' $detail
  }
  foreach ($plugin in $pluginStates.Keys | Sort-Object) { Add-Capability 'plugin' $plugin $true $true ([bool]$pluginStates[$plugin]) 'UNVERIFIED' 'Plugin state read from config; capability probing is task-dependent.' }
} else {
  Add-Capability 'runtime' 'config.toml' $false $false $false 'NOT_RUN' "Configuration file not found: $ConfigPath"
}

# Registry entries that are not observed are still emitted so a missing required
# capability is actionable. This never launches installers or network probes.
foreach ($entry in $registry.Values) {
  if (!($results | Where-Object { $_.type -eq $entry.type -and $_.name -eq $entry.id })) {
    $installed = $false
    if ($entry.type -eq 'skill' -and $entry.installEvidence) { $installed = Test-Path -LiteralPath (Join-Path $CodexHome $entry.installEvidence) -PathType Leaf }
    Add-Capability $entry.type $entry.id $false $installed $false 'NOT_RUN' 'Declared capability was not observed in the active configuration.'
  }
}

if ($Json) { $results | ConvertTo-Json -Depth 4 } else {
  $results | Sort-Object type,name | Format-Table type,name,configured,installed,enabled,callable,health -AutoSize
  $counts = $results | Group-Object health | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }
  Write-Host "Capability health: $($counts -join '; ')"
}
