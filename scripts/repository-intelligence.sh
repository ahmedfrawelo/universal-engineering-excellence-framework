#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
framework_root="$(cd "$script_dir/.." && pwd)"
vendor_root="$framework_root/vendor/repository-intelligence-engine"

if [[ $# -lt 1 ]]; then
  echo "Usage: repository-intelligence.sh <build|query|path|explain|affected|status|doctor> [--root PATH] [options]" >&2
  exit 2
fi
case "$1" in
  build|query|path|explain|affected|status|doctor) ;;
  *) echo "Unsupported repository intelligence command: $1" >&2; exit 2 ;;
esac
if ! command -v uv >/dev/null 2>&1; then
  echo "uv is required to run repository intelligence." >&2
  exit 1
fi
if [[ ! -f "$vendor_root/UEEF-VENDOR.json" ]]; then
  echo "Vendored repository intelligence engine is incomplete: $vendor_root" >&2
  exit 1
fi

export UV_LINK_MODE=copy
exec uv run --frozen --no-dev --project "$vendor_root" ueef-repository-intelligence "$@"
