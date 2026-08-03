#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_base="$(mktemp -d)"
fixture="$tmp_base/repository with spaces"
case "$tmp_base" in
  /tmp/*|/var/*|[A-Za-z]:/*) ;;
  *) echo "Refusing unexpected temporary path: $tmp_base" >&2; exit 1 ;;
esac
trap 'rm -rf -- "$tmp_base"' EXIT HUP INT TERM

mkdir -p "$fixture/src" "$fixture/docs"
printf '%s\n' 'from src.worker import run' '' 'def execute():' '    return run()' > "$fixture/src/service.py"
printf '%s\n' 'def run():' '    return "ready"' > "$fixture/src/worker.py"
printf '%s\n' '# Architecture' > "$fixture/docs/architecture.md"
printf '%s\n' 'api_key=UEEF_SHELL_SECRET_DO_NOT_INDEX' > "$fixture/.env"

build="$(bash "$root/scripts/repository-intelligence.sh" build --root "$fixture" --json)"
query="$(bash "$root/scripts/repository-intelligence.sh" query --root "$fixture" --query execute --json)"
status="$(bash "$root/scripts/repository-intelligence.sh" status --root "$fixture" --json)"
python -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["status"] == "PASS" and d["counts"]["nodes"] > 0' "$build"
python -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["status"] == "PASS" and d["results"]' "$query"
python -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["status"] == "PASS" and d["fresh"] is True' "$status"
if grep -R -Fq 'UEEF_SHELL_SECRET_DO_NOT_INDEX' "$fixture/.ueef/repository-graph"; then
  echo 'Secret-like ignored file content leaked into graph artifacts.' >&2
  exit 1
fi

printf '%s\n' 'Repository intelligence shell tests passed'
