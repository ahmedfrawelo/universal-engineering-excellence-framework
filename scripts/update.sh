#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
git -C "$ROOT" pull --ff-only
echo "Repository updated. Re-run installer for each agent."
