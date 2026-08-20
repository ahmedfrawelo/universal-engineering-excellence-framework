#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
framework_root="$(cd "$script_dir/.." && pwd)"
engine_root="$framework_root/engines/repository-intelligence"

if [[ $# -lt 1 ]]; then
  echo "Usage: repository-intelligence.sh <bootstrap|build|query|path|explain|affected|status|doctor> [--root PATH] [options]" >&2
  exit 2
fi
case "$1" in
  bootstrap|build|query|path|explain|affected|status|doctor) ;;
  *) echo "Unsupported repository intelligence command: $1" >&2; exit 2 ;;
esac
if [[ ! -f "$engine_root/UEEF-UPSTREAM.json" ]]; then
  echo "Embedded repository intelligence engine is incomplete: $engine_root" >&2
  exit 1
fi

export UV_LINK_MODE=copy
venv_root="$engine_root/.venv"
sync_marker="$venv_root/.ueef-sync-signature.sh"
entry_executable="$venv_root/bin/ueef-repository-intelligence"
dependency_signature="$({ printf '%s\n' "engine-root=$engine_root"; cksum "$engine_root/pyproject.toml" "$engine_root/uv.lock"; } | cksum | awk '{print $1 ":" $2}')"
installed_signature="$(cat "$sync_marker" 2>/dev/null || true)"
needs_sync=false
if [[ ! -x "$entry_executable" || "$installed_signature" != "$dependency_signature" ]]; then needs_sync=true; fi
if [[ "$1" == bootstrap ]]; then
  command -v uv >/dev/null 2>&1 || { echo "uv is required to bootstrap repository intelligence." >&2; exit 1; }
  lock_key="$(printf '%s' "$engine_root" | cksum | awk '{print $1}')"
  lock_dir="${TMPDIR:-/tmp}/ueef-repository-intelligence-$lock_key.lock.d"
  lock_acquired=false
  for _ in $(seq 1 450); do
    if mkdir "$lock_dir" 2>/dev/null; then lock_acquired=true; break; fi
    sleep 0.1
  done
  [[ "$lock_acquired" == true ]] || { echo "Timed out waiting for the repository-intelligence dependency bootstrap lock." >&2; exit 1; }
  trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT
  if [[ "$needs_sync" == true ]]; then
    uv sync --frozen --no-dev --project "$engine_root"
    printf '%s\n' "$dependency_signature" > "$sync_marker"
  fi
  rmdir "$lock_dir"
  trap - EXIT
  echo "Repository intelligence dependencies bootstrapped."
  exit 0
fi
if [[ "$needs_sync" == true ]]; then
  echo "Repository intelligence dependencies are missing or stale. Run scripts/repository-intelligence.sh bootstrap explicitly, then retry." >&2
  exit 1
fi
exec "$entry_executable" "$@"
