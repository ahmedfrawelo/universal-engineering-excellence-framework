$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$entrypoint = Join-Path $root 'scripts\repository-intelligence.ps1'
$shellEntrypoint = Join-Path $root 'scripts\repository-intelligence.sh'
$vendorRoot = Join-Path $root 'vendor\repository-intelligence-engine'

foreach ($required in @($entrypoint, $shellEntrypoint, $vendorRoot)) {
  if (!(Test-Path -LiteralPath $required)) { throw "Repository intelligence requirement missing: $required" }
}

$fixture = Join-Path ([IO.Path]::GetTempPath()) "ueef repository intelligence $([guid]::NewGuid().ToString('N'))"
try {
  New-Item -ItemType Directory -Path (Join-Path $fixture 'src'), (Join-Path $fixture 'docs') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $fixture 'src\service.py') -Encoding utf8 -Value @'
from src.worker import run

def execute():
    return run()
'@
  Set-Content -LiteralPath (Join-Path $fixture 'src\worker.py') -Encoding utf8 -Value @'
def run():
    return "ready"
'@
  Set-Content -LiteralPath (Join-Path $fixture 'docs\architecture.md') -Encoding utf8 -Value '# Architecture'
  Set-Content -LiteralPath (Join-Path $fixture '.env') -Encoding utf8 -Value 'api_key=UEEF_TEST_SECRET_DO_NOT_INDEX'

  # Dependency bootstrap is a one-time uv concern and is intentionally excluded
  # from the cold graph-build budget measured by the adapter.
  & uv sync --frozen --no-dev --project $vendorRoot | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Repository intelligence dependency bootstrap did not pass.' }

  $build = & $entrypoint -Command build -Root $fixture -Json | ConvertFrom-Json
  if ($build.status -ne 'PASS') { throw "Build did not pass: $($build | ConvertTo-Json -Compress)" }
  if ($build.durationMs -gt 30000) { throw "Cold fixture build exceeded 30000 ms: $($build.durationMs)" }
  if ($build.command -ne 'build' -or $build.schemaVersion -ne '1.0') { throw 'Build contract is invalid.' }

  $outputRoot = Join-Path $fixture '.ueef\repository-graph'
  foreach ($artifact in @('graph.json', 'GRAPH_REPORT.md', 'graph.html', 'state.json')) {
    if (!(Test-Path -LiteralPath (Join-Path $outputRoot $artifact))) { throw "Build artifact missing: $artifact" }
  }
  $artifactsText = (Get-Content -LiteralPath (Join-Path $outputRoot 'graph.json') -Raw) + (Get-Content -LiteralPath (Join-Path $outputRoot 'GRAPH_REPORT.md') -Raw)
  if ($artifactsText -match 'UEEF_TEST_SECRET_DO_NOT_INDEX') { throw 'Secret-like ignored file content leaked into graph artifacts.' }

  $query = & $entrypoint -Command query -Root $fixture -Query 'execute' -Json | ConvertFrom-Json
  if ($query.status -ne 'PASS' -or @($query.results).Count -lt 1) { throw 'Query did not return a bounded result.' }
  if ($query.durationMs -gt 5000) { throw "Fixture query exceeded 5000 ms: $($query.durationMs)" }

  $path = & $entrypoint -Command path -Root $fixture -From 'execute' -To 'run' -Json | ConvertFrom-Json
  if ($path.status -ne 'PASS' -or @($path.path).Count -lt 2) { throw 'Path did not prove the fixture relationship.' }

  foreach ($command in @('explain', 'affected')) {
    $result = & $entrypoint -Command $command -Root $fixture -Query 'run' -Json | ConvertFrom-Json
    if ($result.status -ne 'PASS') { throw "$command did not pass." }
  }

  $status = & $entrypoint -Command status -Root $fixture -Json | ConvertFrom-Json
  $doctor = & $entrypoint -Command doctor -Root $fixture -Json | ConvertFrom-Json
  if ($status.status -ne 'PASS' -or $doctor.status -ne 'PASS') { throw 'Status or doctor did not pass after a successful build.' }

  $firstState = Get-Content -LiteralPath (Join-Path $outputRoot 'state.json') -Raw | ConvertFrom-Json
  $firstGraph = Get-Content -LiteralPath (Join-Path $outputRoot 'graph.json') -Raw | ConvertFrom-Json
  $firstEdgeCount = @($(if ($firstGraph.edges) { $firstGraph.edges } else { $firstGraph.links })).Count
  Start-Sleep -Milliseconds 50
  $warm = & $entrypoint -Command build -Root $fixture -Json | ConvertFrom-Json
  if ($warm.status -ne 'PASS' -or $warm.cache.reusedFiles -lt 2) { throw 'Warm build did not prove cache reuse.' }
  if ($warm.durationMs -gt 2000) { throw "Warm fixture build exceeded 2000 ms: $($warm.durationMs)" }
  $warmGraph = Get-Content -LiteralPath (Join-Path $outputRoot 'graph.json') -Raw | ConvertFrom-Json
  $warmEdgeCount = @($(if ($warmGraph.edges) { $warmGraph.edges } else { $warmGraph.links })).Count
  if ($warmEdgeCount -ne $firstEdgeCount) { throw 'Warm build duplicated graph edges.' }

  $portableArtifacts = Get-ChildItem -LiteralPath $outputRoot -File -Force | Where-Object { $_.Extension -in @('.json', '.md') -or $_.Name.StartsWith('.') } | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }
  foreach ($artifactText in $portableArtifacts) {
    if ($artifactText -match [regex]::Escape($fixture) -or $artifactText -match '(?i)[A-Z]:[\\/]') { throw 'Machine-specific absolute path leaked into repository graph output.' }
  }

  Remove-Item -LiteralPath (Join-Path $fixture 'src\worker.py')
  $changed = & $entrypoint -Command build -Root $fixture -Json | ConvertFrom-Json
  if ($changed.status -ne 'PASS' -or $changed.cache.deletedFiles -lt 1) { throw 'Incremental build did not prune a deleted file.' }
} finally {
  if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}

$nestedGit = Get-ChildItem -LiteralPath $vendorRoot -Directory -Filter '.git' -Recurse -Force -ErrorAction SilentlyContinue
if ($nestedGit) { throw 'Nested upstream .git metadata must not be vendored.' }
foreach ($notice in @('LICENSE', 'LICENSE-MIT', 'NOTICE', 'UEEF-VENDOR.json', 'MODIFICATIONS.md')) {
  if (!(Test-Path -LiteralPath (Join-Path $vendorRoot $notice))) { throw "Vendor attribution artifact missing: $notice" }
}
$vendorEvidence = & node (Join-Path $root 'scripts\verify-repository-intelligence-vendor.mjs') $root | ConvertFrom-Json
if ($vendorEvidence.status -ne 'PASS' -or $vendorEvidence.upstreamFiles -ne 776 -or $vendorEvidence.nestedGit) { throw 'Vendor inventory verification failed.' }

Write-Output 'Repository intelligence tests passed'
