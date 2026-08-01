[CmdletBinding()]
param(
  [string]$CodexHome = '',
  [switch]$Install,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'resolve-codex-home.ps1')
$CodexHome = Resolve-CodexHome -Override $CodexHome
$manifestPath = Join-Path $root 'config\preferred-capabilities.json'
$skillsPath = Join-Path $root 'config\preferred-skills.json'
if (!(Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Preferred capabilities manifest not found: $manifestPath" }
if (!(Test-Path -LiteralPath $skillsPath -PathType Leaf)) { throw "Preferred skills manifest not found: $skillsPath" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$skills = Get-Content -LiteralPath $skillsPath -Raw | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1) { throw "Unsupported preferred capabilities schema: $($manifest.schemaVersion)" }
if ($skills.schemaVersion -notin @(1,2)) { throw "Unsupported preferred skills schema: $($skills.schemaVersion)" }

if ($Install) {
  $missingSkills = @($skills.preferred | Where-Object {
    !(Test-Path -LiteralPath (Join-Path $CodexHome ([string]$_.installEvidence)) -PathType Leaf)
  })
  if ($missingSkills.Count) {
    & (Join-Path $root 'scripts\install-preferred-skills.ps1') -CodexHome $CodexHome -Skill @($missingSkills.id) | Out-Null
  }
}

$healthDocument = & (Join-Path $root 'scripts\get-capability-health.ps1') -CodexHome $CodexHome -Json | ConvertFrom-Json
$health = [Collections.Generic.List[object]]::new()
foreach ($capability in $healthDocument) { $health.Add($capability) }
$results = [Collections.Generic.List[object]]::new()

foreach ($entry in @($skills.preferred)) {
  $item = $health.Find({ param($candidate) $candidate.type -eq 'skill' -and $candidate.name -eq $entry.id })
  $installed = [bool]$item.installed
  $results.Add([pscustomobject]@{
    type = 'skill'
    id = [string]$entry.id
    level = [string]$entry.level
    management = 'skill-installer'
    declared = if ($item) { [bool]$item.declared } else { $false }
    installed = $installed
    configured = if ($item) { [bool]$item.configured } else { $false }
    enabled = if ($item) { $item.enabled } else { $null }
    health = if ($item) { [string]$item.health } elseif ($installed) { 'CONFIGURED_UNVERIFIED' } else { 'MISSING_DEPENDENCY' }
    action = if ($installed) { 'NONE' } else { "Run scripts/install-preferred-skills.ps1 -Skill $($entry.id)" }
  })
}

foreach ($entry in @($manifest.capabilities)) {
  $entryType = [string]$entry.type
  $entryId = [string]$entry.id
  $item = $health.Find({ param($candidate) $candidate.type -eq $entryType -and $candidate.name -eq $entryId })
  $installed = if ($item) { [bool]$item.installed } else { $false }
  $configured = if ($item) { [bool]$item.configured } else { $false }
  $action = 'NONE'
  if (!$installed -or !$configured) {
    $action = switch ([string]$entry.management) {
      'platform-managed-explicit' { "Install or enable plugin '$($entry.pluginId)' through the Codex plugin platform." }
      'runtime-managed' { "Repair or update the Codex runtime capability '$($entry.id)'." }
      default { "Review preferred capability '$($entry.id)'." }
    }
  }
  $results.Add([pscustomobject]@{
    type = [string]$entry.type
    id = [string]$entry.id
    level = [string]$entry.level
    management = [string]$entry.management
    declared = if ($item) { [bool]$item.declared } else { $false }
    installed = $installed
    configured = $configured
    enabled = if ($item) { $item.enabled } else { $null }
    health = if ($item) { [string]$item.health } else { 'MISSING_DEPENDENCY' }
    action = $action
  })
}

$missing = @($results | Where-Object { !$_.installed -or !$_.configured })
$summary = [pscustomobject]@{
  schemaVersion = 1
  codexHome = $CodexHome
  total = $results.Count
  skills = @($results | Where-Object type -eq 'skill').Count
  plugins = @($results | Where-Object type -eq 'plugin').Count
  mcps = @($results | Where-Object type -eq 'mcp').Count
  missing = $missing.Count
  ready = $missing.Count -eq 0
  installationPerformed = [bool]$Install
  capabilities = $results.ToArray()
}

if ($Json) {
  $summary | ConvertTo-Json -Depth 5
} else {
  $results | Sort-Object type,id | Format-Table type,id,management,installed,configured,enabled,health -AutoSize
  Write-Output "Preferred capabilities: $($summary.total); Skills: $($summary.skills); Plugins: $($summary.plugins); MCPs: $($summary.mcps); Missing: $($summary.missing)"
  foreach ($item in $missing) { Write-Output "Required action: $($item.id) -> $($item.action)" }
  Write-Output "Overall: $(if ($summary.ready) { 'READY' } else { 'READY_WITH_ACTIONS' })"
}
