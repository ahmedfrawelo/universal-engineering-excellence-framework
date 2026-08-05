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
venv_root="$vendor_root/.venv"
sync_marker="$venv_root/.ueef-sync-signature.sh"
entry_executable="$venv_root/bin/ueef-repository-intelligence"
dependency_signature="$(cksum "$vendor_root/pyproject.toml" "$vendor_root/uv.lock" | cksum | awk '{print $1 ":" $2}')"
lock_key="$(printf '%s' "$vendor_root" | cksum | awk '{print $1}')"
lock_dir="${TMPDIR:-/tmp}/ueef-repository-intelligence-$lock_key.lock.d"
lock_acquired=false
for _ in $(seq 1 450); do
  if mkdir "$lock_dir" 2>/dev/null; then lock_acquired=true; break; fi
  sleep 0.1
done
if [[ "$lock_acquired" != true ]]; then
  echo "Timed out waiting for the repository-intelligence dependency bootstrap lock." >&2
  exit 1
fi
trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT
installed_signature="$(cat "$sync_marker" 2>/dev/null || true)"
if [[ ! -x "$entry_executable" || "$installed_signature" != "$dependency_signature" ]]; then
  uv sync --frozen --no-dev --project "$vendor_root"
  printf '%s\n' "$dependency_signature" > "$sync_marker"
fi
rmdir "$lock_dir"
trap - EXIT
exec "$entry_executable" "$@"
