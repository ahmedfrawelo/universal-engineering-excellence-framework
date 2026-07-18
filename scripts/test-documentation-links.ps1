$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
& node (Join-Path $PSScriptRoot 'test-documentation-links.mjs') $root
if ($LASTEXITCODE -ne 0) { throw "Documentation link tests failed with exit code $LASTEXITCODE." }
