$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('ueef-capability-health-' + [guid]::NewGuid().ToString('N'))
try {
  $testCodexHome = Join-Path $sandbox 'codex-home'
  New-Item -ItemType Directory -Path (Join-Path $testCodexHome 'skills\example-skill'),(Join-Path $testCodexHome 'skills\.system\core-skill') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $testCodexHome 'skills\example-skill\SKILL.md') -Value '# example'
  Set-Content -LiteralPath (Join-Path $testCodexHome 'skills\.system\core-skill\SKILL.md') -Value '# core'
  $command = (Get-Command powershell -ErrorAction Stop).Source.Replace('\','\\')
  @"
[plugins."enabled-plugin"]
enabled = true
[plugins."disabled-plugin"]
enabled = false
[mcp_servers.local]
command = "$command"
[mcp_servers.remote]
url = "https://example.test/mcp"
"@ | Set-Content -LiteralPath (Join-Path $testCodexHome 'config.toml') -Encoding utf8
  $doctor = Join-Path $root 'scripts\get-capability-health.ps1'
  $items = & $doctor -CodexHome $testCodexHome -Json | ConvertFrom-Json
  $local = $items | Where-Object { $_.type -eq 'mcp' -and $_.name -eq 'local' }
  $remote = $items | Where-Object { $_.type -eq 'mcp' -and $_.name -eq 'remote' }
  $disabled = $items | Where-Object { $_.type -eq 'plugin' -and $_.name -eq 'disabled-plugin' }
  $skill = $items | Where-Object { $_.type -eq 'skill' -and $_.name -eq 'example-skill' }
  if (!$local.installed -or $local.callable -ne 'UNVERIFIED') { throw 'Local MCP state was misclassified.' }
  if (!$remote.installed -or $remote.health -ne 'CONFIGURED_UNVERIFIED') { throw 'Remote MCP state was misclassified.' }
  if ($disabled.health -ne 'DISABLED') { throw 'Disabled plugin state was misclassified.' }
  if (!$skill.installed -or $skill.callable -ne 'UNVERIFIED') { throw 'Skill state was misclassified.' }
  Write-Host 'Capability health tests passed'
} finally {
  if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
