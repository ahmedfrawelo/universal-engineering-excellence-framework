[CmdletBinding()]
param(
  [string]$CodexHome = '',
  [string]$ConfigPath,
  [string]$RegistryPath = '',
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $PSCommandPath
. (Join-Path $scriptRoot 'resolve-codex-home.ps1')
$CodexHome = Resolve-CodexHome -Override $CodexHome
if ([string]::IsNullOrWhiteSpace($RegistryPath)) { $RegistryPath = Join-Path (Split-Path -Parent $scriptRoot) 'config\capability-registry.json' }
if (!$ConfigPath) { $ConfigPath = Join-Path $CodexHome 'config.toml' }
$results = [Collections.Generic.List[object]]::new()
$registry = @{}
$pluginStates = @{}
if (Test-Path -LiteralPath $RegistryPath -PathType Leaf) {
  $registryDocument = Get-Content -LiteralPath $RegistryPath -Raw | ConvertFrom-Json
  if ($registryDocument.schemaVersion -ne 1) { throw "Unsupported capability registry schema: $($registryDocument.schemaVersion)" }
  foreach ($entry in @($registryDocument.capabilities)) { $registry["$($entry.type)|$($entry.id)"] = $entry }
}

# Preferred skills extend the capability registry from their single pinned
# manifest. This avoids duplicating provenance and trigger policy in two JSON
# files while still making every routed skill declared and health-checkable.
$preferredPath = Join-Path (Split-Path -Parent $RegistryPath) 'preferred-skills.json'
if (Test-Path -LiteralPath $preferredPath -PathType Leaf) {
  $preferredDocument = Get-Content -LiteralPath $preferredPath -Raw | ConvertFrom-Json
  if ($preferredDocument.schemaVersion -notin @(1,2)) { throw "Unsupported preferred skills schema: $($preferredDocument.schemaVersion)" }
  foreach ($entry in @($preferredDocument.preferred)) {
    $key = "skill|$($entry.id)"
    if ($registry.ContainsKey($key)) { continue }
    $kind = if ($entry.source.PSObject.Properties.Name -contains 'kind') { [string]$entry.source.kind } else { 'github' }
    $sourceName = if ($kind -eq 'bundled') { 'UEEF bundled skill' } else { "Pinned skill from $($entry.source.repository)" }
    $versionOrPin = if ($kind -eq 'bundled') { 'runtime-versioned' } else { [string]$entry.source.ref }
    $registry[$key] = [pscustomobject]@{
      type = 'skill'; id = [string]$entry.id; required = $false; source = $sourceName; versionOrPin = $versionOrPin
      installEvidence = [string]$entry.installEvidence
      fallback = "Continue with the matching UEEF pack and report that $($entry.id) is unavailable."
      consumerPacks = @('10-frontend','59-skill-invocation-protocol')
      governance = [pscustomobject]@{ selection=[string]$entry.level; trigger=(@($entry.triggers) -join ', '); policyRefs=@('config/preferred-skills.json') }
      provenance = [pscustomobject]@{ kind=$kind; repository=[string]$entry.source.repository; ref=[string]$entry.source.ref; path=[string]$entry.source.path; installer='scripts/install-preferred-skills.ps1' }
    }
  }
}

function Add-Capability([string]$Type, [string]$Name, [bool]$Configured, [bool]$Installed, [Nullable[bool]]$Enabled, [string]$Callable, [string]$Detail) {
  $declaration = $registry["$Type|$Name"]
  $health = if (!$Configured) { 'NOT_CONFIGURED' } elseif (!$Installed) { 'MISSING_DEPENDENCY' } elseif ($null -eq $Enabled) { 'CONFIGURED_UNVERIFIED' } elseif (!$Enabled) { 'DISABLED' } elseif ($Callable -eq 'PASS') { 'CALLABLE' } else { 'CONFIGURED_UNVERIFIED' }
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
} else {
  Add-Capability 'runtime' 'config.toml' $false $false $false 'NOT_RUN' "Configuration file not found: $ConfigPath"
}

# Plugin cache manifests prove installation only. Explicit config entries prove
# bundled/runtime plugin enablement, while a remote-install marker proves that a
# remote plugin is installed and registered for this Codex home. A remote marker
# alone does not prove enablement, session selection, connection health, OAuth
# state, MCP startup, or live callability.
$observedPluginIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$pluginCacheRoot = Join-Path $CodexHome 'plugins\cache'
if (Test-Path -LiteralPath $pluginCacheRoot -PathType Container) {
  $pluginManifests = @(Get-ChildItem -LiteralPath $pluginCacheRoot -Force -Recurse -Filter 'plugin.json' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Directory.Name -eq '.codex-plugin' } |
    Sort-Object LastWriteTime -Descending)
  foreach ($manifestFile in $pluginManifests) {
    try { $manifest = Get-Content -LiteralPath $manifestFile.FullName -Raw | ConvertFrom-Json -ErrorAction Stop } catch { continue }
    if ([string]::IsNullOrWhiteSpace([string]$manifest.name)) { continue }
    $relative = $manifestFile.FullName.Substring($pluginCacheRoot.Length).TrimStart('\','/')
    $marketplace = ($relative -split '[\\/]')[0]
    if ([string]::IsNullOrWhiteSpace($marketplace)) { continue }
    $pluginId = "$($manifest.name)@$marketplace"
    if (!$observedPluginIds.Add($pluginId)) { continue }

    $versionRoot = Split-Path -Parent (Split-Path -Parent $manifestFile.FullName)
    $pluginOwner = Split-Path -Parent $versionRoot
    $remoteMarker = $false
    $remoteMarkerPath = Join-Path $pluginOwner '.codex-remote-plugin-install.json'
    if (Test-Path -LiteralPath $remoteMarkerPath -PathType Leaf) {
      try {
        $remoteRecord = Get-Content -LiteralPath $remoteMarkerPath -Raw | ConvertFrom-Json -ErrorAction Stop
        $remoteMarker = $remoteRecord.schema_version -eq 1 -and ![string]::IsNullOrWhiteSpace([string]$remoteRecord.remote_plugin_id)
      } catch { $remoteMarker = $false }
    }
    $explicitState = $pluginStates.ContainsKey($pluginId)
    $configured = $explicitState -or $remoteMarker
    $enabled = if ($explicitState) { [Nullable[bool]]([bool]$pluginStates[$pluginId]) } else { $null }
    $evidence = if ($explicitState) { 'explicit config entry' } elseif ($remoteMarker) { 'remote installation marker' } else { 'cache manifest only' }
    $manifestWarnings = [Collections.Generic.List[string]]::new()
    $defaultPrompts = @($manifest.interface.defaultPrompt)
    if ($defaultPrompts.Count -gt 3) { $manifestWarnings.Add("interface.defaultPrompt has $($defaultPrompts.Count) entries; Codex supports at most 3.") }
    for ($promptIndex = 0; $promptIndex -lt $defaultPrompts.Count; $promptIndex++) {
      if ([string]$defaultPrompts[$promptIndex] -and ([string]$defaultPrompts[$promptIndex]).Length -gt 128) {
        $manifestWarnings.Add("interface.defaultPrompt[$promptIndex] exceeds 128 characters.")
      }
    }
    Add-Capability 'plugin' $pluginId $configured $true $enabled 'UNVERIFIED' "Plugin manifest version $($manifest.version) found with $evidence; enablement, session selection, connection state, and live tools were not inferred from a remote marker."
    if ($configured -and $enabled -ne $false -and $manifestWarnings.Count) {
      $pluginResult = $results[$results.Count - 1]
      $pluginResult.callable = 'WARN'
      $pluginResult.health = 'DEGRADED'
      $pluginResult.detail = "Plugin manifest is installed but partially rejected by Codex: $($manifestWarnings -join ' ')"
    }

    if ($manifest.skills) {
      $skillsPath = [IO.Path]::GetFullPath((Join-Path $versionRoot ([string]$manifest.skills)))
      if (Test-Path -LiteralPath $skillsPath -PathType Container) {
        foreach ($skillDirectory in Get-ChildItem -LiteralPath $skillsPath -Force -Directory -ErrorAction SilentlyContinue) {
          $entrypoint = Join-Path $skillDirectory.FullName 'SKILL.md'
          if (!(Test-Path -LiteralPath $entrypoint -PathType Leaf)) { continue }
          $skillName = "$($manifest.name):$($skillDirectory.Name)"
          Add-Capability 'skill' $skillName $configured $true $enabled 'UNVERIFIED' "Plugin SKILL.md found in $pluginId; provider readiness follows $evidence, while task selection remains unverified."
          $agentConfig = Join-Path $skillDirectory.FullName 'agents\openai.yaml'
          if ($configured -and $enabled -ne $false -and (Test-Path -LiteralPath $agentConfig -PathType Leaf)) {
            $pluginAssetsPrefix = [IO.Path]::GetFullPath((Join-Path $versionRoot 'assets')).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
            $iconWarnings = [Collections.Generic.List[string]]::new()
            foreach ($line in Get-Content -LiteralPath $agentConfig) {
              if ($line -notmatch '^\s*icon_(small|large):\s*["'']?([^"'']+?)["'']?\s*$') { continue }
              $iconPath = [string]$matches[2]
              $resolvedIcon = [IO.Path]::GetFullPath((Join-Path $skillDirectory.FullName $iconPath))
              $escapesSkill = $iconPath -match '(^|[\\/])\.\.([\\/]|$)'
              if (!(Test-Path -LiteralPath $resolvedIcon -PathType Leaf) -or ($escapesSkill -and !$resolvedIcon.StartsWith($pluginAssetsPrefix, [StringComparison]::OrdinalIgnoreCase))) {
                $iconWarnings.Add($iconPath)
              }
            }
            if ($iconWarnings.Count) {
              $skillResult = $results[$results.Count - 1]
              $skillResult.callable = 'WARN'
              $skillResult.health = 'DEGRADED'
              $skillResult.detail = 'Skill icon metadata points to a missing file or escapes outside the plugin assets directory and may be rejected by Codex.'
            }
          }
        }
      }
    }
  }
}

# Config can refer to a plugin whose cache payload is absent. Emit that state as
# a missing dependency instead of assuming every configured plugin is installed.
foreach ($plugin in $pluginStates.Keys | Sort-Object) {
  if (!$observedPluginIds.Contains($plugin)) {
    Add-Capability 'plugin' $plugin $true $false ([bool]$pluginStates[$plugin]) 'NOT_RUN' 'Plugin is configured, but no matching cache manifest was found.'
  }
}

# CALLABLE is deliberately a narrow static-local claim. It is allowed only for
# a registry-bound skill whose own SKILL.md exists and whose exact provider
# plugin is explicitly enabled. No process, network, or session-selection probe
# is performed; every other observed capability remains UNVERIFIED.
foreach ($item in $results | Where-Object { $_.type -eq 'skill' }) {
  $declaration = $registry["skill|$($item.name)"]
  $evidence = if ($declaration) { $declaration.callableEvidence } else { $null }
  if ($evidence -and $evidence.kind -eq 'local-skill-file-and-enabled-plugin' -and $evidence.pluginId) {
    $pluginId = [string]$evidence.pluginId
    if (!$item.installed) { $item.callable='NOT_RUN';$item.health='MISSING_DEPENDENCY';$item.detail='Callable evidence rejected: the declared SKILL.md is missing.' }
    elseif (!$pluginStates.ContainsKey($pluginId)) { $item.callable='NOT_RUN';$item.health='NOT_CONFIGURED';$item.detail="Callable evidence not configured: provider plugin $pluginId is not declared." }
    elseif (!$pluginStates[$pluginId]) { $item.callable='NOT_RUN';$item.health='DISABLED';$item.detail="Callable evidence rejected: provider plugin $pluginId is disabled." }
    else { $item.callable='PASS';$item.health='CALLABLE';$item.detail="Static callable evidence: SKILL.md exists and provider plugin $pluginId is enabled; no process, network, or session probe was run." }
  }
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

if ($Json) { ConvertTo-Json -InputObject $results.ToArray() -Depth 4 } else {
  $results | Sort-Object type,name | Format-Table type,name,configured,installed,enabled,callable,health -AutoSize
  $counts = $results | Group-Object health | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }
  Write-Host "Capability health: $($counts -join '; ')"
}
