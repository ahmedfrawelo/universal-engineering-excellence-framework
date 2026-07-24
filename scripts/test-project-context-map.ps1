$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$fixture = Join-Path ([IO.Path]::GetTempPath()) "ueef context map $([guid]::NewGuid().ToString('N'))"

try {
  New-Item -ItemType Directory -Path (Join-Path $fixture '.openai'), (Join-Path $fixture 'src'), (Join-Path $fixture 'scripts'), (Join-Path $fixture 'specs'), (Join-Path $fixture '.github\workflows'), (Join-Path $fixture 'packages\sample\node_modules'), (Join-Path $fixture 'packages\sample\dist') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $fixture 'release-manifest.json') -Value '{}'
  Set-Content -LiteralPath (Join-Path $fixture '.openai\hosting.json') -Value '{}'
  Set-Content -LiteralPath (Join-Path $fixture 'scripts\test-example.ps1') -Value "Write-Output 'ok'"

  $output = (& (Join-Path $root 'scripts\project-context-map.ps1') -Path $fixture -MaxItems 100) -join "`n"
  foreach ($term in @('release-manifest.json', '.openai/hosting.json', 'src', 'scripts/test-example.ps1', '.github', 'packages/sample/node_modules', 'packages/sample/dist')) {
    if ($output -notmatch [regex]::Escape($term)) { throw "Project context map missing: $term" }
  foreach ($item in @('specs', 'scripts/test-example.ps1')) {
    if ($output -notmatch "(?m)^- $([regex]::Escape($item))$") { throw "Project context map did not emit a separate test candidate: $item" }
  }
  }

  $rejected = $false
  try { & (Join-Path $root 'scripts\project-context-map.ps1') -Path $fixture -MaxItems 0 | Out-Null } catch { $rejected = $true }
  if (!$rejected) { throw 'Project context map accepted MaxItems 0.' }
} finally {
  if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}

Write-Output 'Project context map tests passed'
