$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$registry = Get-Content -LiteralPath (Join-Path $root 'config\capability-registry.json') -Raw | ConvertFrom-Json
$preferred = Get-Content -LiteralPath (Join-Path $root 'config\preferred-skills.json') -Raw | ConvertFrom-Json
foreach ($id in @($preferred.preferred.id)) {
  $entry = $registry.capabilities | Where-Object { $_.type -eq 'skill' -and $_.id -eq $id }
  if ($entry -and (!$entry.governance -or !$entry.provenance -or !$entry.installEvidence -or !$entry.fallback)) { throw "Explicit registry governance/provenance contract incomplete for $id." }
}
if (($registry.capabilities | Where-Object { $_.id -in @('ui-ux-pro-max','impeccable') -and $_.required }).Count) { throw 'UI baseline skills must not be global-required.' }
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('ueef-capability-health-' + [guid]::NewGuid().ToString('N'))
try {
  $testCodexHome = Join-Path $sandbox 'codex-home'
  function New-TestPlugin([string]$Marketplace,[string]$Name,[string]$SkillName='',[switch]$RemoteInstalled,[switch]$InvalidPrompt) {
    $pluginOwner = Join-Path $testCodexHome "plugins\cache\$Marketplace\$Name"
    $versionRoot = Join-Path $pluginOwner '1.0.0'
    $manifestDirectory = Join-Path $versionRoot '.codex-plugin'
    New-Item -ItemType Directory -Path $manifestDirectory -Force | Out-Null
    $manifest = [ordered]@{name=$Name;version='1.0.0'}
    if ($InvalidPrompt) { $manifest.interface = @{ defaultPrompt=@('one','two','three','four') } }
    if ($SkillName) {
      $manifest.skills = './skills/'
      $skillDirectory = Join-Path $versionRoot "skills\$SkillName"
      New-Item -ItemType Directory -Path $skillDirectory -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $skillDirectory 'SKILL.md') -Value "# $SkillName"
    }
    $manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $manifestDirectory 'plugin.json') -Encoding utf8
    if ($RemoteInstalled) {
      '{"schema_version":1,"remote_plugin_id":"fixture"}' | Set-Content -LiteralPath (Join-Path $pluginOwner '.codex-remote-plugin-install.json') -Encoding utf8
    }
  }

  New-Item -ItemType Directory -Path (Join-Path $testCodexHome 'skills\example-skill'),(Join-Path $testCodexHome 'skills\.system\core-skill') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $testCodexHome 'skills\example-skill\SKILL.md') -Value '# example'
  New-Item -ItemType Directory -Path (Join-Path $testCodexHome 'skills\callable-skill') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $testCodexHome 'skills\callable-skill\SKILL.md') -Value '# callable'
  Set-Content -LiteralPath (Join-Path $testCodexHome 'skills\.system\core-skill\SKILL.md') -Value '# core'
  New-TestPlugin openai-bundled enabled-plugin plugin-skill
  New-TestPlugin openai-bundled disabled-plugin
  New-TestPlugin openai-bundled callable-provider
  New-TestPlugin openai-bundled cached-only cached-skill
  New-TestPlugin openai-bundled degraded-plugin degraded-skill -InvalidPrompt
  New-TestPlugin openai-bundled degraded-skill-provider icon-skill
  $invalidAgentDirectory = Join-Path $testCodexHome 'plugins\cache\openai-bundled\degraded-skill-provider\1.0.0\skills\icon-skill\agents'
  New-Item -ItemType Directory -Path $invalidAgentDirectory -Force | Out-Null
  "interface:`n  icon_small: ../shared/icon.png" | Set-Content -LiteralPath (Join-Path $invalidAgentDirectory 'openai.yaml') -Encoding utf8
  New-TestPlugin openai-curated-remote remote-plugin remote-skill -RemoteInstalled
  $command = (Get-Command powershell -ErrorAction Stop).Source.Replace('\','\\')
  @"
[plugins."enabled-plugin@openai-bundled"]
enabled = true
[plugins."disabled-plugin@openai-bundled"]
enabled = false
[plugins."callable-provider@openai-bundled"]
enabled = true
[plugins."degraded-plugin@openai-bundled"]
enabled = true
[plugins."degraded-skill-provider@openai-bundled"]
enabled = true
[plugins."missing-plugin@openai-bundled"]
enabled = true
[mcp_servers.local]
command = "$command"
[mcp_servers.remote]
url = "https://example.test/mcp"
"@ | Set-Content -LiteralPath (Join-Path $testCodexHome 'config.toml') -Encoding utf8
  $registryPath=Join-Path $sandbox 'registry.json'
  '{"schemaVersion":1,"capabilities":[{"type":"skill","id":"callable-skill","required":false,"source":"fixture","versionOrPin":"fixture","installEvidence":"skills/callable-skill/SKILL.md","fallback":"none","consumerPacks":[],"callableEvidence":{"kind":"local-skill-file-and-enabled-plugin","pluginId":"callable-provider@openai-bundled"}}]}' | Set-Content -LiteralPath $registryPath -Encoding utf8
  $doctor = Join-Path $root 'scripts\get-capability-health.ps1'
  $declaredPreferred = & $doctor -CodexHome $testCodexHome -Json | ConvertFrom-Json
  foreach ($id in @($preferred.preferred.id)) {
    $item = $declaredPreferred | Where-Object { $_.type -eq 'skill' -and $_.name -eq $id }
    if (!$item -or !$item.declared) { throw "Preferred skill was not synthesized into capability health: $id" }
  }
  $items = & $doctor -CodexHome $testCodexHome -RegistryPath $registryPath -Json | ConvertFrom-Json
  $previousCodexHome = $env:CODEX_HOME
  try {
    $env:CODEX_HOME = $testCodexHome
    $defaultItems = & $doctor -RegistryPath $registryPath -Json | ConvertFrom-Json
  } finally {
    $env:CODEX_HOME = $previousCodexHome
  }
  $local = $items | Where-Object { $_.type -eq 'mcp' -and $_.name -eq 'local' }
  $remote = $items | Where-Object { $_.type -eq 'mcp' -and $_.name -eq 'remote' }
  $disabled = $items | Where-Object { $_.type -eq 'plugin' -and $_.name -eq 'disabled-plugin@openai-bundled' }
  $pluginSkill = $items | Where-Object { $_.type -eq 'skill' -and $_.name -eq 'enabled-plugin:plugin-skill' }
  $remotePlugin = $items | Where-Object { $_.type -eq 'plugin' -and $_.name -eq 'remote-plugin@openai-curated-remote' }
  $remoteSkill = $items | Where-Object { $_.type -eq 'skill' -and $_.name -eq 'remote-plugin:remote-skill' }
  $cachedOnly = $items | Where-Object { $_.type -eq 'plugin' -and $_.name -eq 'cached-only@openai-bundled' }
  $degradedPlugin = $items | Where-Object { $_.type -eq 'plugin' -and $_.name -eq 'degraded-plugin@openai-bundled' }
  $degradedSkill = $items | Where-Object { $_.type -eq 'skill' -and $_.name -eq 'degraded-skill-provider:icon-skill' }
  $missingPlugin = $items | Where-Object { $_.type -eq 'plugin' -and $_.name -eq 'missing-plugin@openai-bundled' }
  $skill = $items | Where-Object { $_.type -eq 'skill' -and $_.name -eq 'example-skill' }
  $callable = $items | Where-Object { $_.type -eq 'skill' -and $_.name -eq 'callable-skill' }
  if (!$local.installed -or $local.callable -ne 'UNVERIFIED') { throw 'Local MCP state was misclassified.' }
  if (!$remote.installed -or $remote.health -ne 'CONFIGURED_UNVERIFIED') { throw 'Remote MCP state was misclassified.' }
  if ($disabled.health -ne 'DISABLED') { throw 'Disabled plugin state was misclassified.' }
  if (!$pluginSkill.installed -or !$pluginSkill.enabled -or $pluginSkill.health -ne 'CONFIGURED_UNVERIFIED') { throw 'Plugin-owned skill was omitted or misclassified.' }
  if (!$remotePlugin.configured -or !$remotePlugin.installed -or $null -ne $remotePlugin.enabled -or $remotePlugin.health -ne 'CONFIGURED_UNVERIFIED') { throw 'Remote installed plugin was omitted, falsely enabled, or misclassified.' }
  if (!$remoteSkill.configured -or !$remoteSkill.installed -or $null -ne $remoteSkill.enabled -or $remoteSkill.callable -ne 'UNVERIFIED') { throw 'Remote plugin-owned skill was omitted, falsely enabled, or misclassified.' }
  if (!$cachedOnly.installed -or $cachedOnly.configured -or $cachedOnly.health -ne 'NOT_CONFIGURED') { throw 'Cache-only plugin must not be reported as configured.' }
  if ($degradedPlugin.health -ne 'DEGRADED' -or $degradedPlugin.callable -ne 'WARN') { throw 'Invalid configured plugin manifest must be reported as degraded.' }
  if ($degradedSkill.health -ne 'DEGRADED' -or $degradedSkill.callable -ne 'WARN') { throw 'Escaping plugin skill icon path must be reported as degraded.' }
  if ($missingPlugin.installed -or $missingPlugin.health -ne 'MISSING_DEPENDENCY') { throw 'Configured plugin without a cache manifest must be reported missing.' }
  if (!$skill.installed -or $skill.callable -ne 'UNVERIFIED') { throw 'Skill state was misclassified.' }
  if ($callable.callable -ne 'PASS' -or $callable.health -ne 'CALLABLE' -or $callable.detail -notmatch 'no process, network, or session probe') { throw 'Static callable contract failed.' }
  if (($defaultItems | Where-Object { $_.type -eq 'mcp' -and $_.name -eq 'local' }).health -ne 'CONFIGURED_UNVERIFIED') { throw 'Capability health default Codex home did not honor the portable CODEX_HOME environment.' }
  Write-Host 'Capability health tests passed'
} finally {
  if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
