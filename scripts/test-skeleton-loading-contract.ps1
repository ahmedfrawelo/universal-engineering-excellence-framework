$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$required = @{
  'framework/53-skeleton-loading/07-render-timing-and-flicker-control.md' = @('reveal delay', 'minimum visible duration', 'feature code must not create independent magic-number timers', 'deterministic clocks')
  'framework/53-skeleton-loading/08-ssr-hydration-and-streaming.md' = @('deterministic skeleton structure', 'hydration', 'streaming boundaries', 'reverting to a client skeleton')
  'framework/53-skeleton-loading/09-shared-skeleton-api-and-registry.md' = @('public API', 'component registry', 'two real consumers', 'architecture or lint check', 'Component Family Organization', 'parallel shared folders', 'consumes the canonical primitive')
  'framework/27-quality-gates/25-skeleton-loading-gate.md' = @('shared reveal/minimum-duration policy', 'hydration mismatch', 'duplicated local primitive')
  'framework/29-checklists/34-skeleton-loading-checklist.md' = @('Fast, normal, slow', 'SSR, hydration', 'design-system public API')
  'framework/38-templates/22-skeleton-loading-contract-template.md' = @('Reveal-delay token:', 'Minimum-visible-duration token:', 'Server/client structure parity:', 'Duplicate-local-primitive architecture check:')
  'framework/03-runtime/00-runtime-sequence.md' = @('Skeleton timing policy selected:', 'Delayed reveal verified:', 'Minimum visible duration verified:', 'SSR/hydration parity verified:', 'Shared skeleton API contract verified:', 'Skeleton family owner and canonical public import verified:', 'Cancellation and refresh behavior verified:')
  'framework/01-core/01-master-loader.md' = @('timing, SSR/hydration, and shared-API modules', 'public API, and component registry')
  'framework/46-design-system-consistency-reuse/06-shared-frontend-services-validation-api.md' = @('Shared skeleton services', 'content-preserving refresh')
  'framework/48-design-governance/16-component-registry.md' = @('Skeleton entries include', 'duplicate-detection evidence')
  'framework/46-design-system-consistency-reuse/00-unified-design-system-architecture.md' = @('one owned folder', 'multiple sibling shared folders', 'reuse when the contract fits')
  'UEEF-LOADER.md' = @('one owned family folder', 'does not justify parallel implementations')
  'scripts/sync-runtime.ps1' = @('one owned family folder', 'search all shared roots and imports')
}

foreach ($relative in $required.Keys) {
  $path = Join-Path $root $relative
  if (!(Test-Path -LiteralPath $path)) { throw "Missing skeleton contract file: $relative" }
  $text = Get-Content -LiteralPath $path -Raw
  foreach ($term in $required[$relative]) {
    if ($text -notmatch [regex]::Escape($term)) { throw "Skeleton contract term '$term' missing from $relative." }
  }
}

$indexText = Get-Content -LiteralPath (Join-Path $root 'framework/53-skeleton-loading/INDEX.md') -Raw
foreach ($module in @('07-render-timing-and-flicker-control.md', '08-ssr-hydration-and-streaming.md', '09-shared-skeleton-api-and-registry.md')) {
  if ($indexText -notmatch [regex]::Escape($module)) { throw "Skeleton index missing $module." }
}

Write-Host 'Skeleton loading contract tests passed'
