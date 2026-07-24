$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$registry = Get-Content -LiteralPath (Join-Path $root 'config\capability-registry.json') -Raw | ConvertFrom-Json
foreach ($id in @('ui-ux-pro-max','impeccable','design-brief')) {
  $entry = $registry.capabilities | Where-Object { $_.type -eq 'skill' -and $_.id -eq $id }
  if (!$entry -or !$entry.governance -or !$entry.provenance -or !$entry.installEvidence -or !$entry.fallback) { throw "Registry governance/provenance contract missing for $id." }
}
if (($registry.capabilities | Where-Object { $_.id -in @('ui-ux-pro-max','impeccable') -and $_.required }).Count) { throw 'UI baseline skills must not be global-required.' }
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('ueef-capability-health-' + [guid]::NewGuid().ToString('N'))
try {
  $testCodexHome = Join-Path $sandbox 'codex-home'
  New-Item -ItemType Directory -Path (Join-Path $testCodexHome 'skills\example-skill'),(Join-Path $testCodexHome 'skills\.system\core-skill') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $testCodexHome 'skills\example-skill\SKILL.md') -Value '# example'
  New-Item -ItemType Directory -Path (Join-Path $testCodexHome 'skills\callable-skill') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $testCodexHome 'skills\callable-skill\SKILL.md') -Value '# callable'
  Set-Content -LiteralPath (Join-Path $testCodexHome 'skills\.system\core-skill\SKILL.md') -Value '# core'
  $command = (Get-Command powershell -ErrorAction Stop).Source.Replace('\','\\')
  @"
[plugins."enabled-plugin"]
enabled = true
[plugins."disabled-plugin"]
enabled = false
[plugins."callable-provider"]
enabled = true
[mcp_servers.local]
command = "$command"
[mcp_servers.remote]
url = "https://example.test/mcp"
"@ | Set-Content -LiteralPath (Join-Path $testCodexHome 'config.toml') -Encoding utf8
  $registryPath=Join-Path $sandbox 'registry.json'
  '{"schemaVersion":1,"capabilities":[{"type":"skill","id":"callable-skill","required":false,"source":"fixture","versionOrPin":"fixture","installEvidence":"skills/callable-skill/SKILL.md","fallback":"none","consumerPacks":[],"callableEvidence":{"kind":"local-skill-file-and-enabled-plugin","pluginId":"callable-provider"}}]}' | Set-Content -LiteralPath $registryPath -Encoding utf8
  $doctor = Join-Path $root 'scripts\get-capability-health.ps1'
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
  $disabled = $items | Where-Object { $_.type -eq 'plugin' -and $_.name -eq 'disabled-plugin' }
  $skill = $items | Where-Object { $_.type -eq 'skill' -and $_.name -eq 'example-skill' }
  $callable = $items | Where-Object { $_.type -eq 'skill' -and $_.name -eq 'callable-skill' }
  if (!$local.installed -or $local.callable -ne 'UNVERIFIED') { throw 'Local MCP state was misclassified.' }
  if (!$remote.installed -or $remote.health -ne 'CONFIGURED_UNVERIFIED') { throw 'Remote MCP state was misclassified.' }
  if ($disabled.health -ne 'DISABLED') { throw 'Disabled plugin state was misclassified.' }
  if (!$skill.installed -or $skill.callable -ne 'UNVERIFIED') { throw 'Skill state was misclassified.' }
  if ($callable.callable -ne 'PASS' -or $callable.health -ne 'CALLABLE' -or $callable.detail -notmatch 'no process, network, or session probe') { throw 'Static callable contract failed.' }
  if (($defaultItems | Where-Object { $_.type -eq 'mcp' -and $_.name -eq 'local' }).health -ne 'CONFIGURED_UNVERIFIED') { throw 'Capability health default Codex home did not honor the portable CODEX_HOME environment.' }
  Write-Host 'Capability health tests passed'
} finally {
  if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
