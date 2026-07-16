#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

for file in \
  "$ROOT/framework/53-skeleton-loading/07-render-timing-and-flicker-control.md" \
  "$ROOT/framework/53-skeleton-loading/08-ssr-hydration-and-streaming.md" \
  "$ROOT/framework/53-skeleton-loading/09-shared-skeleton-api-and-registry.md"; do
  [ -f "$file" ] || { echo "Missing skeleton contract file: $file" >&2; exit 1; }
done

for term in 'reveal delay' 'minimum visible duration' 'deterministic clocks'; do
  grep -Fq "$term" "$ROOT/framework/53-skeleton-loading/07-render-timing-and-flicker-control.md" || { echo "Missing timing term: $term" >&2; exit 1; }
done
for term in 'deterministic skeleton structure' 'hydration' 'streaming boundaries' 'reverting to a client skeleton'; do
  grep -Fq "$term" "$ROOT/framework/53-skeleton-loading/08-ssr-hydration-and-streaming.md" || { echo "Missing rendering term: $term" >&2; exit 1; }
done
for term in 'public API' 'component registry' 'two real consumers' 'architecture or lint check'; do
  grep -Fq "$term" "$ROOT/framework/53-skeleton-loading/09-shared-skeleton-api-and-registry.md" || { echo "Missing shared API term: $term" >&2; exit 1; }
done
for term in 'Skeleton timing policy selected:' 'Delayed reveal verified:' 'Minimum visible duration verified:' 'SSR/hydration parity verified:' 'Shared skeleton API contract verified:' 'Cancellation and refresh behavior verified:'; do
  grep -Fq "$term" "$ROOT/framework/03-runtime/00-runtime-sequence.md" || { echo "Missing runtime skeleton field: $term" >&2; exit 1; }
done
grep -Fq 'Shared skeleton services' "$ROOT/framework/46-design-system-consistency-reuse/06-shared-frontend-services-validation-api.md" || { echo 'Missing shared service skeleton contract' >&2; exit 1; }
grep -Fq 'Skeleton entries include' "$ROOT/framework/48-design-governance/16-component-registry.md" || { echo 'Missing skeleton registry metadata contract' >&2; exit 1; }

printf '%s\n' 'Skeleton loading contract tests passed'
