#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "${1:-$(dirname -- "$0")/..}" && pwd)
node "$ROOT/scripts/test-documentation-links.mjs" "$ROOT"
