#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "${1:-$(dirname -- "$0")/..}" && pwd)
fail=0
pass() { printf 'PASS %s\n' "$1"; }
fail_check() { printf 'FAIL %s: %s\n' "$1" "$2" >&2; fail=1; }
if sh "$ROOT/scripts/validate-framework.sh" >/dev/null; then pass framework-validation; else fail_check framework-validation validator-failed; fi
if git -C "$ROOT" diff --check; then pass git-clean-diff; else fail_check git-clean-diff whitespace-errors; fi
if git -C "$ROOT" ls-files -- 'dist' 'build' 'coverage' 'test-results' 'playwright-report' '*.log' '*.tmp' | grep -q .; then fail_check tracked-generated-artifacts tracked-files-found; else pass tracked-generated-artifacts; fi
if find "$ROOT/scripts" -name '*.mjs' -print0 | xargs -0 -r -n1 node --check; then pass script-syntax; else fail_check script-syntax node-check-failed; fi
version=$(sed -n 's/.*version: \([0-9][0-9.]*\).*/\1/p' "$ROOT/VERSION.md" | head -n1)
if grep -q "\"version\": \"$version\"" "$ROOT/release-manifest.json"; then pass release-parity; else fail_check release-parity version-mismatch; fi
if [ "$fail" -eq 0 ]; then echo "UEEF audit: PASS"; else echo "UEEF audit: FAIL" >&2; exit 1; fi
