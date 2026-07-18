param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'

$required = @(
  'docs/specifications/application-evolution-runtime-performance.md',
  'framework/61-project-modernization/00-project-modernization-system.md',
  'framework/61-project-modernization/01-discovery-and-baseline.md',
  'framework/61-project-modernization/02-behavior-preserving-refactoring.md',
  'framework/61-project-modernization/03-dead-and-obsolete-code.md',
  'framework/61-project-modernization/05-technology-currency-assessment.md',
  'framework/61-project-modernization/06-upgrade-decision-and-execution.md',
  'framework/61-project-modernization/07-performance-freshness-and-lazy-loading.md',
  'framework/27-quality-gates/34-project-modernization-and-runtime-gate.md',
  'framework/29-checklists/43-project-modernization-and-runtime-checklist.md',
  'framework/38-templates/30-project-modernization-plan-template.md',
  'scripts/project-technology-inventory.mjs'
)
foreach ($file in $required) { if (!(Test-Path -LiteralPath (Join-Path $Root $file))) { throw "Missing modernization contract: $file" } }

$text = ($required | ForEach-Object { Get-Content -LiteralPath (Join-Path $Root $_) -Raw }) -join "`n"
foreach ($term in @('characterization tests','dynamic imports','current and target versions','explicit user decision','without page reload','lazy','rollback','authoritative')) {
  if ($text -notmatch [regex]::Escape($term)) { throw "Modernization contract missing: $term" }
}
$liveRefresh = Get-Content -LiteralPath (Join-Path $Root 'framework/47-theme-responsive-interaction-security-performance/51-global-live-refresh.md') -Raw
foreach ($term in @('WebSocket','Origin','SSE','Retry-After','one retry owner','backpressure','no-page-reload evidence')) {
  if ($liveRefresh -notmatch [regex]::Escape($term)) { throw "Global live-refresh contract missing: $term" }
}
$lazyLoading = Get-Content -LiteralPath (Join-Path $Root 'framework/47-theme-responsive-interaction-security-performance/50-application-lazy-loading.md') -Raw
foreach ($term in @('request waterfalls','duplicate vendor chunks','reserved layout','first user request','measured before/after evidence')) {
  if ($lazyLoading -notmatch [regex]::Escape($term)) { throw "Application lazy-loading contract missing: $term" }
}

$inventory = & node (Join-Path $Root 'scripts/project-technology-inventory.mjs') $Root | ConvertFrom-Json
if (!$inventory.entries -or !$inventory.ecosystems) { throw 'Technology inventory did not return repository evidence' }

$fixture = Join-Path ([IO.Path]::GetTempPath()) ("ueef-technology-inventory-" + [guid]::NewGuid())
try {
  New-Item -ItemType Directory -Path (Join-Path $fixture '.github/workflows') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $fixture 'package.json') -Encoding utf8 -Value '{"packageManager":"npm@11.0.0","engines":{"node":">=22"},"dependencies":{"example":"1.2.3"}}'
  Set-Content -LiteralPath (Join-Path $fixture 'sample.csproj') -Encoding utf8 -Value '<Project><PropertyGroup><TargetFramework>net9.0</TargetFramework></PropertyGroup><ItemGroup><PackageReference Include="Example" Version="2.0.0" /></ItemGroup></Project>'
  Set-Content -LiteralPath (Join-Path $fixture 'requirements.txt') -Encoding utf8 -Value 'example==3.0.0'
  Set-Content -LiteralPath (Join-Path $fixture 'pom.xml') -Encoding utf8 -Value '<project><modelVersion>4.0.0</modelVersion></project>'
  Set-Content -LiteralPath (Join-Path $fixture 'go.mod') -Encoding utf8 -Value "module example.test`ngo 1.24"
  Set-Content -LiteralPath (Join-Path $fixture 'Cargo.toml') -Encoding utf8 -Value '[package]'
  Set-Content -LiteralPath (Join-Path $fixture 'Dockerfile') -Encoding utf8 -Value 'FROM node:22-alpine'
  Set-Content -LiteralPath (Join-Path $fixture '.github/workflows/ci.yml') -Encoding utf8 -Value 'steps: [{ uses: actions/checkout@v4 }]'
  $fixtureInventory = & node (Join-Path $Root 'scripts/project-technology-inventory.mjs') $fixture | ConvertFrom-Json
  foreach ($ecosystem in @('node','dotnet','python','java','go','rust','container','ci')) {
    if ($fixtureInventory.ecosystems -notcontains $ecosystem) { throw "Technology inventory missed fixture ecosystem: $ecosystem" }
  }
  $nodeManifest = $fixtureInventory.entries | Where-Object path -eq 'package.json'
  if ($nodeManifest.details.dependencies.example -ne '1.2.3') { throw 'Technology inventory missed Node dependency evidence' }
  $dotnetManifest = $fixtureInventory.entries | Where-Object path -eq 'sample.csproj'
  if ($dotnetManifest.details.targetFrameworks -notcontains 'net9.0') { throw 'Technology inventory missed .NET target framework evidence' }
} finally {
  Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host 'Project modernization contract tests passed'
