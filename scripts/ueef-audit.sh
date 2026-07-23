#!/usr/bin/env sh
set -eu

MODE=full
JSON=false
ROOT_ARGUMENT=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --quick) MODE=quick ;;
    --json) JSON=true ;;
    --root) shift; [ "$#" -gt 0 ] || { echo 'Missing --root value' >&2; exit 2; }; ROOT_ARGUMENT=$1 ;;
    *) [ -z "$ROOT_ARGUMENT" ] || { echo "Unexpected argument: $1" >&2; exit 2; }; ROOT_ARGUMENT=$1 ;;
  esac
  shift
done
ROOT=$(CDPATH= cd -- "${ROOT_ARGUMENT:-$(dirname -- "$0")/..}" && pwd)
GIT_ROOT="$ROOT"
if [ ! -d "$GIT_ROOT/.git" ]; then
  STATE_PATH="$(dirname "$ROOT")/UEEF-ACTIVE.json"
  if [ -f "$STATE_PATH" ]; then
    GIT_ROOT=$(sed -n 's/.*"sourceRepositoryPath"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$STATE_PATH" | sed -n '1p')
    GIT_ROOT=$(printf '%s' "$GIT_ROOT" | sed 's/\\\\/\\/g')
    if command -v cygpath >/dev/null 2>&1; then GIT_ROOT=$(cygpath -u "$GIT_ROOT"); fi
  fi
fi

RESULTS="${TMPDIR:-/tmp}/ueef-audit-results.$$"
trap 'rm -f "$RESULTS"' EXIT HUP INT TERM
: > "$RESULTS"
FAIL=0
now_ms() { date +%s%3N; }
record() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$RESULTS"; }
run_check() {
  name=$1
  shift
  start=$(now_ms)
  if "$@" >/dev/null 2>&1; then status=PASS; detail=''; else status=FAIL; detail=check-failed; FAIL=1; fi
  end=$(now_ms)
  duration=$((end - start))
  record "$name" "$status" "$duration" "$detail"
  if [ "$JSON" = false ]; then
    if [ "$status" = PASS ]; then printf 'PASS %s (%sms)\n' "$name" "$duration"; else printf 'FAIL %s: %s (%sms)\n' "$name" "$detail" "$duration" >&2; fi
  fi
}

check_source_hygiene() {
  if find "$ROOT" -path "$ROOT/.git" -prune -o -type f \( -name '.env' -o -name '.env.*' -o -name '*.pem' -o -name '*.key' -o -name '*.pfx' -o -name '*.p12' -o -name 'id_rsa' -o -name 'id_ed25519' -o -name 'credentials.json' -o -name 'service-account*.json' \) -print | grep -q .; then return 1; fi
  ! git -C "$GIT_ROOT" grep -n -I -E -e '-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}' -- . ':(exclude)scripts/ueef-audit.ps1' ':(exclude)scripts/ueef-audit.sh' >/dev/null 2>&1
}
check_git_diff() { test -d "$GIT_ROOT/.git" && git -C "$GIT_ROOT" diff --check; }
check_generated() { ! git -C "$GIT_ROOT" ls-files -- 'dist' 'build' 'coverage' 'test-results' 'playwright-report' '*.log' '*.tmp' | grep -q .; }
check_runtime_policy() {
  destination="${TMPDIR:-/tmp}/ueef-audit-copy.$$"
  trap 'rm -f "$RESULTS"; rm -rf -- "$destination"' EXIT HUP INT TERM
  node "$ROOT/scripts/copy-release-files.mjs" "$ROOT" "$destination" --include-loader >/dev/null 2>&1
  outcome=$?
  rm -rf -- "$destination"
  return "$outcome"
}

run_check framework-validation sh "$ROOT/scripts/validate-framework.sh"
run_check git-clean-diff check_git_diff
run_check source-hygiene check_source_hygiene
run_check tracked-generated-artifacts check_generated
run_check script-syntax sh "$ROOT/scripts/test-script-syntax.sh"
run_check release-parity sh "$ROOT/scripts/test-release-consistency.sh" "$ROOT"
run_check project-context-map sh "$ROOT/scripts/test-project-context-map.sh"
run_check documentation-paths sh "$ROOT/scripts/test-documentation-links.sh" "$ROOT"
run_check framework-indexes node "$ROOT/scripts/test-framework-indexes.mjs" "$ROOT"
run_check runtime-file-policy check_runtime_policy

if [ "$JSON" = true ]; then
  node - "$RESULTS" "$MODE" "$FAIL" <<'NODE'
const fs = require('node:fs');
const [resultPath, mode, failed] = process.argv.slice(2);
const checks = fs.readFileSync(resultPath, 'utf8').trim().split(/\r?\n/).filter(Boolean).map((line) => {
  const [name, status, durationMs, detail] = line.split('\t');
  const check = { name, status, durationMs: Number(durationMs) };
  if (detail) check.detail = detail;
  return check;
});
process.stdout.write(`${JSON.stringify({ schemaVersion: 1, generatedAt: new Date().toISOString(), root: '<project-root>', mode, status: failed === '0' ? 'PASS' : 'FAIL', checks })}\n`);
NODE
elif [ "$FAIL" -eq 0 ]; then
  echo "UEEF audit: PASS ($MODE)"
else
  echo "UEEF audit: FAIL ($MODE)" >&2
fi
[ "$FAIL" -eq 0 ]
