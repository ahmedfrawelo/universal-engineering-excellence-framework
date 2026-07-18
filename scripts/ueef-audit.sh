#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "${1:-$(dirname -- "$0")/..}" && pwd)
GIT_ROOT="$ROOT"
if [ ! -d "$GIT_ROOT/.git" ]; then
  STATE_PATH="$(dirname "$ROOT")/UEEF-ACTIVE.json"
  if [ -f "$STATE_PATH" ]; then
    GIT_ROOT=$(sed -n 's/.*"sourceRepositoryPath"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$STATE_PATH" | sed -n '1p')
    GIT_ROOT=$(printf '%s' "$GIT_ROOT" | sed 's/\\\\/\\/g')
    if command -v cygpath >/dev/null 2>&1; then GIT_ROOT=$(cygpath -u "$GIT_ROOT"); fi
  fi
fi
fail=0
pass() { printf 'PASS %s\n' "$1"; }
fail_check() { printf 'FAIL %s: %s\n' "$1" "$2" >&2; fail=1; }
if sh "$ROOT/scripts/validate-framework.sh" >/dev/null; then pass framework-validation; else fail_check framework-validation validator-failed; fi
if [ -d "$GIT_ROOT/.git" ] && git -C "$GIT_ROOT" diff --check; then pass git-clean-diff; else fail_check git-clean-diff source-git-unavailable-or-whitespace-errors; fi
if find "$ROOT" -path "$ROOT/.git" -prune -o -type f \( -name '.env' -o -name '.env.*' -o -name '*.pem' -o -name '*.key' -o -name '*.pfx' -o -name '*.p12' -o -name 'id_rsa' -o -name 'id_ed25519' -o -name 'credentials.json' -o -name 'service-account*.json' \) -print | grep -q .; then fail_check source-hygiene sensitive-files-found
elif git -C "$GIT_ROOT" grep -n -I -E -e '-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}' -- . ':(exclude)scripts/ueef-audit.ps1' ':(exclude)scripts/ueef-audit.sh' >/dev/null 2>&1; then fail_check source-hygiene secret-like-content
else pass source-hygiene; fi
if git -C "$GIT_ROOT" ls-files -- 'dist' 'build' 'coverage' 'test-results' 'playwright-report' '*.log' '*.tmp' | grep -q .; then fail_check tracked-generated-artifacts tracked-files-found; else pass tracked-generated-artifacts; fi
if sh "$ROOT/scripts/test-script-syntax.sh" >/dev/null; then pass script-syntax; else fail_check script-syntax cross-platform-parse-failed; fi
if sh "$ROOT/scripts/test-release-consistency.sh" "$ROOT" >/dev/null; then pass release-parity; else fail_check release-parity release-metadata-or-documentation-mismatch; fi
if sh "$ROOT/scripts/test-project-context-map.sh" >/dev/null; then pass project-context-map; else fail_check project-context-map context-map-contract-failed; fi
if sh "$ROOT/scripts/test-documentation-links.sh" "$ROOT" >/dev/null; then pass documentation-paths; else fail_check documentation-paths documentation-path-contract-failed; fi
if node "$ROOT/scripts/test-framework-indexes.mjs" "$ROOT" >/dev/null; then pass framework-indexes; else fail_check framework-indexes framework-index-contract-failed; fi
if node "$ROOT/scripts/copy-release-files.mjs" "$ROOT" "${TMPDIR:-/tmp}/ueef-audit-copy.$$" --include-loader >/dev/null 2>&1; then rm -rf -- "${TMPDIR:-/tmp}/ueef-audit-copy.$$"; pass runtime-file-policy; else fail_check runtime-file-policy release-copy-policy-failed; fi
if [ "$fail" -eq 0 ]; then echo "UEEF audit: PASS"; else echo "UEEF audit: FAIL" >&2; exit 1; fi
