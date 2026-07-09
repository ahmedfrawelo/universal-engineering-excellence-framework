#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT"
if [ -d ".git" ]; then
  git pull --ff-only
fi
echo "Repository refreshed. Run the installer for each assistant you use."
