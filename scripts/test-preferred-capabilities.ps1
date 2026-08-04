$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -LiteralPath (Join-Path $root 'config\preferred-capabilities.json') -Raw | ConvertFrom-Json
$skills = Get-Content -LiteralPath (Join-Path $root 'config\preferred-skills.json') -Raw | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1) { throw 'Unsupported preferred-capabilities schema.' }
if ($manifest.policy.skillsManifest -ne 'config/preferred-skills.json') { throw 'Preferred skills manifest reference is missing.' }
if ($manifest.policy.reconciler -ne 'scripts/reconcile-preferred-capabilities.ps1') { throw 'Preferred capability reconciler reference is missing.' }

$allowedTypes = @('plugin','mcp')
$allowedManagement = @('runtime-managed','platform-managed-explicit')
$ids = @($manifest.capabilities | ForEach-Object { "$($_.type)|$($_.id)" })
if (($ids | Select-Object -Unique).Count -ne $ids.Count) { throw 'Duplicate preferred capability identifiers.' }
foreach ($entry in @($manifest.capabilities)) {
  if ($entry.type -notin $allowedTypes) { throw "Unsupported preferred capability type: $($entry.type)" }
  if ($entry.management -notin $allowedManagement) { throw "Unsupported preferred capability management: $($entry.id)" }
  if ($entry.management -eq 'platform-managed-explicit' -and [string]::IsNullOrWhiteSpace([string]$entry.pluginId)) {
    throw "Platform-managed plugin is missing pluginId: $($entry.id)"
  }
  if ($entry.type -eq 'mcp' -and $entry.management -ne 'runtime-managed') { throw "MCP must be runtime-managed: $($entry.id)" }
}

$expectedPlugins = @(
  'chrome@openai-bundled','browser@openai-bundled','computer-use@openai-bundled','visualize@openai-bundled','sites@openai-bundled',
  'documents@openai-primary-runtime','pdf@openai-primary-runtime','spreadsheets@openai-primary-runtime',
  'presentations@openai-primary-runtime','template-creator@openai-primary-runtime','github@openai-curated-remote',
  'figma@openai-curated-remote','google-drive@openai-curated-remote','data-analytics@openai-curated-remote','openai-templates@openai-curated-remote'
)
foreach ($id in $expectedPlugins) {
  if (!($manifest.capabilities | Where-Object { $_.type -eq 'plugin' -and $_.id -eq $id })) { throw "Missing preferred plugin: $id" }
}
foreach ($mcpId in @('node_repl','penpot')) {
  if (!($manifest.capabilities | Where-Object { $_.type -eq 'mcp' -and $_.id -eq $mcpId })) { throw "Preferred MCP is missing: $mcpId" }
}
$windowsInstaller = Get-Content -LiteralPath (Join-Path $root 'scripts\install-codex.ps1') -Raw
$unixInstaller = Get-Content -LiteralPath (Join-Path $root 'scripts\install-codex.sh') -Raw
if ($windowsInstaller -notmatch 'InstallPreferredCapabilities' -or $windowsInstaller -notmatch 'reconcile-preferred-capabilities\.ps1') { throw 'Windows installer is not wired to preferred capability reconciliation.' }
if ($unixInstaller -notmatch 'install-preferred-capabilities' -or $unixInstaller -notmatch 'reconcile-preferred-capabilities\.ps1') { throw 'Unix installer is not wired to preferred capability reconciliation.' }

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("ueef-preferred-capabilities-" + [guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory -Path (Join-Path $tempRoot 'skills') -Force | Out-Null
  foreach ($skill in @($skills.preferred)) {
    $skillRoot = Join-Path $tempRoot (Split-Path -Parent ([string]$skill.installEvidence))
    New-Item -ItemType Directory -Path $skillRoot -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $tempRoot ([string]$skill.installEvidence)) -Value "---`nname: $($skill.id)`ndescription: test`n---`n" -Encoding utf8
  }
  $command = if ($env:ComSpec) { $env:ComSpec } else { (Get-Command pwsh -ErrorAction Stop).Source }
  $config = @(
    '[mcp_servers.node_repl]',
    "command = '$command'",
    '[mcp_servers.penpot]',
    "url = 'http://localhost:4401/mcp'",
    'enabled = true',
    'required = false'
  )
  foreach ($entry in @($manifest.capabilities | Where-Object type -eq 'plugin')) {
    $parts = [string]$entry.id -split '@',2
    $name = $parts[0]; $marketplace = $parts[1]
    $pluginRoot = Join-Path $tempRoot "plugins\cache\$marketplace\$name"
    $manifestRoot = Join-Path $pluginRoot '1.0.0\.codex-plugin'
    New-Item -ItemType Directory -Path $manifestRoot -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $manifestRoot 'plugin.json') -Value (ConvertTo-Json @{name=$name;version='1.0.0'}) -Encoding utf8
    if ($entry.management -eq 'platform-managed-explicit') {
      Set-Content -LiteralPath (Join-Path $pluginRoot '.codex-remote-plugin-install.json') -Value '{"schema_version":1,"remote_plugin_id":"test"}' -Encoding utf8
    } else {
      $config += "[plugins.`"$($entry.id)`"]"
      $config += 'enabled = true'
    }
  }
  Set-Content -LiteralPath (Join-Path $tempRoot 'config.toml') -Value $config -Encoding utf8
  $report = & (Join-Path $root 'scripts\reconcile-preferred-capabilities.ps1') -CodexHome $tempRoot -Json | ConvertFrom-Json
  $expectedTotal = @($skills.preferred).Count + @($manifest.capabilities).Count
  if ($report.total -ne $expectedTotal -or $report.skills -ne @($skills.preferred).Count -or $report.plugins -ne 15 -or $report.mcps -ne 2) {
    throw 'Preferred capability reconciliation counts are incorrect.'
  }
  if (!$report.ready -or !$report.fullyAvailable -or $report.missing -ne 0 -or $report.blockingUnavailable -ne 0) { throw 'Complete preferred capability fixture was not READY.' }
  if (@($report.capabilities | Where-Object { !$_.declared }).Count) { throw 'A preferred capability was not declared by capability health.' }
  $remote = $report.capabilities | Where-Object id -eq 'github@openai-curated-remote'
  if ($remote.management -ne 'platform-managed-explicit' -or !$remote.installed -or !$remote.configured) { throw 'Remote plugin registration was not recognized.' }

  Remove-Item -LiteralPath (Join-Path $tempRoot 'plugins\cache\openai-curated-remote\github') -Recurse -Force
  $missingReport = & (Join-Path $root 'scripts\reconcile-preferred-capabilities.ps1') -CodexHome $tempRoot -Json | ConvertFrom-Json
  $missingGitHub = $missingReport.capabilities | Where-Object id -eq 'github@openai-curated-remote'
  if (!$missingReport.ready -or $missingReport.fullyAvailable -or $missingReport.blockingUnavailable -ne 0 -or $missingGitHub.blocking -or $missingGitHub.installed -or $missingGitHub.configured -or $missingGitHub.action -notmatch 'Codex plugin platform') {
    throw "Missing platform plugin did not produce the required explicit action: $($missingGitHub | ConvertTo-Json -Compress)"
  }

  $configPath = Join-Path $tempRoot 'config.toml'
  $disabledConfig = (Get-Content -LiteralPath $configPath -Raw) -replace '(?m)^enabled = true\s*\r?\nrequired = false', "enabled = false`r`nrequired = false"
  Set-Content -LiteralPath $configPath -Value $disabledConfig -Encoding utf8
  $disabledReport = & (Join-Path $root 'scripts\reconcile-preferred-capabilities.ps1') -CodexHome $tempRoot -Json | ConvertFrom-Json
  $penpot = $disabledReport.capabilities | Where-Object id -eq 'penpot'
  if (!$disabledReport.ready -or $disabledReport.fullyAvailable -or $penpot.enabled -ne $false -or $penpot.available -or $penpot.blocking) {
    throw "Disabled conditional Penpot was not reported accurately: $($penpot | ConvertTo-Json -Compress)"
  }
  & (Join-Path $root 'scripts\set-penpot-mcp-state.ps1') -State Disable -CodexHome $tempRoot | Out-Null
  $roundTrip = Get-Content -LiteralPath $configPath -Raw
  if ($roundTrip -notmatch '(?m)^\[mcp_servers\.penpot\]\r?$' -or $roundTrip -notmatch '(?m)^enabled = false\r?$' -or $roundTrip -notmatch '(?m)^required = false\r?$' -or $roundTrip -notmatch '(?m)^\[plugins\.') {
    throw 'Penpot state command damaged the following TOML sections or failed to persist the fast default.'
  }
} finally {
  if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}

Write-Output "Preferred capability tests passed ($(@($skills.preferred).Count) skills, 15 plugins, 2 MCPs)."
