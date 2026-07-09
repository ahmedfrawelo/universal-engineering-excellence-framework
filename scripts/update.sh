#!/usr/bin/env sh
set -eu
git pull --ff-only
echo "Repository updated. Re-run installer for each agent."
