$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$fixture = Join-Path ([IO.Path]::GetTempPath()) "ueef context map $([guid]::NewGuid().ToString('N'))"

try {
  New-Item -ItemType Directory -Path (Join-Path $fixture '.openai'), (Join-Path $fixture 'src'), (Join-Path $fixture 'scripts'), (Join-Path $fixture 'specs'), (Join-Path $fixture '.github\workflows'), (Join-Path $fixture 'packages\sample\node_modules'), (Join-Path $fixture 'packages\sample\dist'), (Join-Path $fixture 'vendor\engine\.venv\Lib\site-packages\fake'), (Join-Path $fixture 'vendor\engine\graphifyy.egg-info'), (Join-Path $fixture 'vendor\engine\shared'), (Join-Path $fixture 'vendor\engine\tests') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $fixture 'release-manifest.json') -Value '{}'
  Set-Content -LiteralPath (Join-Path $fixture '.openai\hosting.json') -Value '{}'
  Set-Content -LiteralPath (Join-Path $fixture 'scripts\test-example.ps1') -Value "Write-Output 'ok'"
  Set-Content -LiteralPath (Join-Path $fixture 'vendor\engine\.venv\Lib\site-packages\fake\package.json') -Value '{}'
  Set-Content -LiteralPath (Join-Path $fixture 'vendor\engine\graphifyy.egg-info\package.json') -Value '{}'
  Set-Content -LiteralPath (Join-Path $fixture 'vendor\engine\pyproject.toml') -Value '[project]'
  Set-Content -LiteralPath (Join-Path $fixture 'vendor\engine\shared\library.py') -Value 'pass'
  Set-Content -LiteralPath (Join-Path $fixture 'vendor\engine\tests\test_vendor.py') -Value 'def test_vendor(): pass'

  $output = (& (Join-Path $root 'scripts\project-context-map.ps1') -Path $fixture -MaxItems 100) -join "`n"
  foreach ($term in @('Repository intelligence: NOT_BUILT', 'release-manifest.json', '.openai/hosting.json', 'src', 'scripts/test-example.ps1', '.github', 'packages/sample/node_modules', 'packages/sample/dist')) {
    if ($output -notmatch [regex]::Escape($term)) { throw "Project context map missing: $term" }
  }
  foreach ($item in @('specs', 'scripts/test-example.ps1')) {
    if ($output -notmatch "(?m)^- $([regex]::Escape($item))$") { throw "Project context map did not emit a separate test candidate: $item" }
  }
  foreach ($forbidden in @('vendor/engine/pyproject.toml','vendor/engine/shared','vendor/engine/tests','site-packages/fake/package.json','graphifyy.egg-info/package.json')) {
    if ($output -match [regex]::Escape($forbidden)) { throw "Project context map traversed generated content: $forbidden" }
  }

  New-Item -ItemType Directory -Path (Join-Path $fixture '.ueef\repository-graph') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $fixture '.ueef\repository-graph\state.json') -Value '{"status":"PASS"}'
  $builtOutput = (& (Join-Path $root 'scripts\project-context-map.ps1') -Path $fixture -MaxItems 100) -join "`n"
  if ($builtOutput -notmatch 'Repository intelligence: BUILT') { throw 'Project context map did not expose built repository intelligence state.' }

  $rejected = $false
  try { & (Join-Path $root 'scripts\project-context-map.ps1') -Path $fixture -MaxItems 0 | Out-Null } catch { $rejected = $true }
  if (!$rejected) { throw 'Project context map accepted MaxItems 0.' }
} finally {
  if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}

Write-Output 'Project context map tests passed'
