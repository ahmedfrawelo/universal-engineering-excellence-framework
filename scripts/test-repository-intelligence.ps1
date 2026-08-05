$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$entrypoint = Join-Path $root 'scripts\repository-intelligence.ps1'
$shellEntrypoint = Join-Path $root 'scripts\repository-intelligence.sh'
$engineRoot = Join-Path $root 'engines\repository-intelligence'

foreach ($required in @($entrypoint, $shellEntrypoint, $engineRoot)) {
  if (!(Test-Path -LiteralPath $required)) { throw "Repository intelligence requirement missing: $required" }
}

$fixture = Join-Path ([IO.Path]::GetTempPath()) "ueef repository intelligence $([guid]::NewGuid().ToString('N'))"
try {
  New-Item -ItemType Directory -Path (Join-Path $fixture 'src'), (Join-Path $fixture 'docs'), (Join-Path $fixture 'assets'), (Join-Path $fixture 'vendor\ignored-package') -Force | Out-Null
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
  Set-Content -LiteralPath (Join-Path $fixture 'assets\logo.bin') -Encoding utf8 -Value 'UEEF_TEST_NON_AST_FILE'
  Set-Content -LiteralPath (Join-Path $fixture '.env') -Encoding utf8 -Value 'api_key=UEEF_TEST_SECRET_DO_NOT_INDEX'
  Set-Content -LiteralPath (Join-Path $fixture 'vendor\ignored-package\ignored.py') -Encoding utf8 -Value 'def must_not_be_indexed(): return "ignored"'

  # The wrapper owns one-time dependency bootstrap. The adapter's durationMs
  # remains the graph-build budget, while later commands must use --no-sync.
  $build = & $entrypoint -Command build -Root $fixture -Json | ConvertFrom-Json
  if ($build.status -ne 'PASS') { throw "Build did not pass: $($build | ConvertTo-Json -Compress)" }
  if ($build.durationMs -gt 30000) { throw "Cold fixture build exceeded 30000 ms: $($build.durationMs)" }
  if ($build.command -ne 'build' -or $build.schemaVersion -ne '1.0') { throw 'Build contract is invalid.' }

  $outputRoot = Join-Path $fixture '.ueef\repository-graph'
  foreach ($artifact in @('graph.json', 'GRAPH_REPORT.md', 'graph.html', 'state.json')) {
    if (!(Test-Path -LiteralPath (Join-Path $outputRoot $artifact))) { throw "Build artifact missing: $artifact" }
  }
  $viewer = Get-Content -LiteralPath (Join-Path $outputRoot 'graph.html') -Raw -Encoding utf8
  foreach ($viewerContract in @('RAW_NODES', 'RAW_EDGES', 'FULL_NODES', 'FULL_EDGES', 'SEARCH_NODES', 'ROUTING_EVIDENCE', 'new vis.Network', 'loadNeighborhood', 'resetOverview', 'hiddenCommunities.clear()', 'id="graph"', 'id="graph-toolbar"', 'id="fit-graph"', 'id="zoom-in"', 'id="zoom-out"', 'id="reset-overview"', 'id="view-state"', 'id="routing-panel"', 'id="routing-summary"', 'id="routing-toggle"', 'aria-expanded="false"', 'id="routing-list" hidden', 'Colors represent architecture ownership and extracted clusters', 'id="search"', 'id="info-panel"', 'id="legend"', 'role="application"', 'role="toolbar"', 'role="listbox"', 'aria-live="polite"', "el.setAttribute('role', 'option')", 'keyboard: { enabled: true', '@media (max-width: 720px)')) {
    if ($viewer -notmatch [regex]::Escape($viewerContract)) { throw "Interactive graph viewer contract missing: $viewerContract" }
  }
  if ($viewer -match 'https://unpkg.com') { throw 'Interactive graph viewer retained a network CDN dependency.' }
  if ($viewer -match '<main id="results">') { throw 'Legacy flat node-list viewer is still present.' }
  $legendMatch = [regex]::Match($viewer, 'const LEGEND = (\[.*?\]);', [Text.RegularExpressions.RegexOptions]::Singleline)
  if (!$legendMatch.Success) { throw 'Interactive graph viewer legend payload is missing.' }
  $legend = @($legendMatch.Groups[1].Value | ConvertFrom-Json)
  if (@($legend | Group-Object label | Where-Object Count -gt 1).Count -gt 0) { throw 'Interactive graph viewer contains duplicate community labels.' }
  $fullNodeRecordMatch = [regex]::Match($viewer, 'const FULL_NODE_RECORDS = (\[.*?\]);\s*const FULL_EDGE_RECORDS', [Text.RegularExpressions.RegexOptions]::Singleline)
  $fullEdgeRecordMatch = [regex]::Match($viewer, 'const FULL_EDGE_RECORDS = (\[.*?\]);\s*const FULL_NODES', [Text.RegularExpressions.RegexOptions]::Singleline)
  if (!$fullNodeRecordMatch.Success -or !$fullEdgeRecordMatch.Success) { throw 'Full graph search records are missing.' }
  $viewerGraph = Get-Content -LiteralPath (Join-Path $outputRoot 'graph.json') -Raw | ConvertFrom-Json
  $viewerGraphNodes = @($viewerGraph.nodes)
  $viewerGraphEdges = @($(if ($viewerGraph.edges) { $viewerGraph.edges } else { $viewerGraph.links }))
  $fullNodeRecords = $fullNodeRecordMatch.Groups[1].Value | ConvertFrom-Json
  $fullEdgeRecords = $fullEdgeRecordMatch.Groups[1].Value | ConvertFrom-Json
  if (@($viewerGraphNodes | Where-Object { [string]$_.source_file -like 'vendor/*' }).Count -ne 0) { throw 'Ignored vendor sources leaked into the repository graph.' }
  if (@($viewerGraphNodes | Where-Object { [string]$_.source_file -eq 'assets/logo.bin' -and [string]$_._origin -eq 'ueef-file-tree' }).Count -lt 1) { throw 'Complete project file tree did not include a non-AST project file.' }
  if (@($viewerGraphEdges | Where-Object { [string]$_.target -like 'ueef_file_assets_logo_bin' -and [string]$_.relation -eq 'contains' }).Count -lt 1) { throw 'Complete project file tree did not connect the non-AST file to its folder.' }
  if ($viewer -match '\u00C2|\u00C3') { throw 'Interactive graph viewer contains mojibake.' }
  if ($fullNodeRecords.Count -lt $viewerGraphNodes.Count) { throw "Full graph search index dropped graph nodes: $($fullNodeRecords.Count) < $($viewerGraphNodes.Count)." }
  if ($fullEdgeRecords.Count -ne $viewerGraphEdges.Count) { throw "Full graph search index dropped graph edges: $($fullEdgeRecords.Count) != $($viewerGraphEdges.Count)." }
  $viewerAssetRoot = Join-Path $outputRoot 'assets\vis-network-9.1.6'
  foreach ($viewerAsset in @('vis-network.min.js', 'LICENSE-MIT', 'LICENSE-APACHE-2.0', 'README.txt')) {
    if (!(Test-Path -LiteralPath (Join-Path $viewerAssetRoot $viewerAsset) -PathType Leaf)) { throw "Offline viewer asset missing: $viewerAsset" }
  }
  $viewerAssetHash = (Get-FileHash -Algorithm SHA384 -LiteralPath (Join-Path $viewerAssetRoot 'vis-network.min.js')).Hash
  if ($viewerAssetHash -ne '531EA986273D3C41C9DFC62DAE28E1933C89F324251FC8BFF9BB8147CB3798064E26B3F5830CAF01C218977196B695F5') { throw 'Offline viewer asset does not match Graphify upstream pinned SRI.' }
  $paletteDistance = & (Join-Path $engineRoot '.venv\Scripts\python.exe') -c 'from graphify.ueef_adapter import UEEF_COMMUNITY_COLORS, UEEF_MIN_PALETTE_DISTANCE, _minimum_palette_distance; print(_minimum_palette_distance(UEEF_COMMUNITY_COLORS)); assert _minimum_palette_distance(UEEF_COMMUNITY_COLORS) >= UEEF_MIN_PALETTE_DISTANCE'
  if ($LASTEXITCODE -ne 0 -or [double]$paletteDistance -lt 35) { throw 'Repository graph palette contains perceptually similar community colors.' }
  $viewerRuntimeTest = Join-Path $root 'scripts\test-repository-intelligence-viewer.mjs'
  $viewerRuntimeResult = & node $viewerRuntimeTest (Join-Path $outputRoot 'graph.html') execute | ConvertFrom-Json
  if ($LASTEXITCODE -ne 0 -or $viewerRuntimeResult.status -ne 'PASS') { throw 'Interactive graph viewer runtime test failed.' }
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
  if ($firstState.viewerVersion -ne '4.7.0') { throw 'Interactive graph viewer version was not persisted.' }
  if ($firstState.counts.files -le $firstState.counts.indexableFiles) { throw 'Project file-tree count did not exceed the analysis-only inventory count in the fixture.' }
  $firstGraph = Get-Content -LiteralPath (Join-Path $outputRoot 'graph.json') -Raw | ConvertFrom-Json
  $firstEdgeCount = @($(if ($firstGraph.edges) { $firstGraph.edges } else { $firstGraph.links })).Count
  Start-Sleep -Milliseconds 50
  $warm = & $entrypoint -Command build -Root $fixture -Json | ConvertFrom-Json
  if ($warm.status -ne 'PASS' -or $warm.cache.reusedFiles -lt 2) { throw 'Warm build did not prove cache reuse.' }
  if ($warm.durationMs -gt 2000) { throw "Warm fixture build exceeded 2000 ms: $($warm.durationMs)" }
  $warmGraph = Get-Content -LiteralPath (Join-Path $outputRoot 'graph.json') -Raw | ConvertFrom-Json
  $warmEdgeCount = @($(if ($warmGraph.edges) { $warmGraph.edges } else { $warmGraph.links })).Count
  if ($warmEdgeCount -ne $firstEdgeCount) { throw 'Warm build duplicated graph edges.' }

  $warmWrapperOutput = (& $entrypoint -Command status -Root $fixture -Json 2>&1 | Out-String)
  if ($warmWrapperOutput -match '(?i)Installed 1 package|Uninstalled 1 package') { throw 'Warm repository-intelligence wrapper redundantly reinstalled the embedded package.' }

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

$nestedGit = Get-ChildItem -LiteralPath $engineRoot -Directory -Filter '.git' -Recurse -Force -ErrorAction SilentlyContinue
if ($nestedGit) { throw 'Nested upstream .git metadata must not be embedded.' }
foreach ($notice in @('LICENSE', 'LICENSE-MIT', 'NOTICE', 'UEEF-UPSTREAM.json', 'MODIFICATIONS.md')) {
  if (!(Test-Path -LiteralPath (Join-Path $engineRoot $notice))) { throw "Engine attribution artifact missing: $notice" }
}
$engineEvidence = & node (Join-Path $root 'scripts\verify-repository-intelligence-engine.mjs') $root | ConvertFrom-Json
if ($engineEvidence.status -ne 'PASS' -or $engineEvidence.upstreamFiles -ne 776 -or $engineEvidence.nestedGit) { throw 'Engine inventory verification failed.' }

Write-Output 'Repository intelligence tests passed'
