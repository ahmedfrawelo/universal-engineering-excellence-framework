#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "${1:-$(dirname -- "$0")/..}" && pwd)
fail=0
pass() { printf 'PASS %s\n' "$1"; }
fail_check() { printf 'FAIL %s: %s\n' "$1" "$2" >&2; fail=1; }
if sh "$ROOT/scripts/validate-framework.sh" >/dev/null; then pass framework-validation; else fail_check framework-validation validator-failed; fi
if git -C "$ROOT" diff --check; then pass git-clean-diff; else fail_check git-clean-diff whitespace-errors; fi
if find "$ROOT" -path "$ROOT/.git" -prune -o -type f \( -name '.env' -o -name '*.pem' -o -name '*.key' -o -name 'id_rsa' \) -print | grep -q .; then fail_check source-hygiene sensitive-files-found
elif git -C "$ROOT" grep -n -I -E -e '-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}' -- . ':(exclude)scripts/ueef-audit.ps1' ':(exclude)scripts/ueef-audit.sh' >/dev/null 2>&1; then fail_check source-hygiene secret-like-content
else pass source-hygiene; fi
if git -C "$ROOT" ls-files -- 'dist' 'build' 'coverage' 'test-results' 'playwright-report' '*.log' '*.tmp' | grep -q .; then fail_check tracked-generated-artifacts tracked-files-found; else pass tracked-generated-artifacts; fi
if find "$ROOT/scripts" -name '*.mjs' -print0 | xargs -0 -r -n1 node --check; then pass script-syntax; else fail_check script-syntax node-check-failed; fi
if find "$ROOT/scripts" -name '*.sh' -type f -exec sh -n {} \;; then pass shell-syntax; else fail_check shell-syntax sh-parse-failed; fi
version=$(sed -n 's/.*version: \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' "$ROOT/VERSION.md" | head -n1)
if grep -q "\"version\": \"$version\"" "$ROOT/release-manifest.json"; then pass release-parity; else fail_check release-parity version-mismatch; fi
if grep -q 'Refusing to sync from inside CODEX_HOME' "$ROOT/scripts/sync-runtime.ps1" && grep -q 'runtimeRootPrefix' "$ROOT/scripts/sync-runtime.ps1"; then pass runtime-path-safety; else fail_check runtime-path-safety missing-controls; fi
if [ "$fail" -eq 0 ]; then echo "UEEF audit: PASS"; else echo "UEEF audit: FAIL" >&2; exit 1; fi
