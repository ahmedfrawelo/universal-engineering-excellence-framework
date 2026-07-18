#!/usr/bin/env sh
set -eu

REPOSITORY_PATH=${1:?repository path required}
RUNTIME_ROOT=${2:?runtime root required}
AGENT=${3:?agent required}
SOURCE_REPOSITORY_PATH=${4:-$REPOSITORY_PATH}
CODEX_HOME=${5:-$(dirname "$RUNTIME_ROOT")}
REQUIRE_AGENTS=${6:-0}

version=$(sed -n 's/.*[Vv]ersion:[[:space:]]*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' "$REPOSITORY_PATH/VERSION.md" | sed -n '1p')
[ -n "$version" ] || { echo 'Could not read VERSION.md' >&2; exit 1; }
runtime_path="$RUNTIME_ROOT/$AGENT"
loader_path="$runtime_path/UEEF-LOADER.md"
agents_path="$CODEX_HOME/AGENTS.md"
agents_ok=true
[ "$REQUIRE_AGENTS" = 1 ] && [ ! -f "$agents_path" ] && agents_ok=false
for required in "$loader_path" "$runtime_path/framework/01-core/00-core-system.md" "$runtime_path/framework/01-core/01-master-loader.md" "$runtime_path/framework/01-core/02-master-index.md" "$runtime_path/framework/27-quality-gates/16-ueef-activation-gate.md" "$runtime_path/scripts/ueef-status.sh"; do
  [ -f "$required" ] || { echo "Required runtime file missing: $required" >&2; exit 1; }
done
mkdir -p "$RUNTIME_ROOT"
state_path="$RUNTIME_ROOT/UEEF-ACTIVE.json"
sh "$REPOSITORY_PATH/scripts/validate-framework.sh" "$REPOSITORY_PATH" >/dev/null
node "$REPOSITORY_PATH/scripts/active-state.mjs" write "$state_path" "$version" "$CODEX_HOME" "$RUNTIME_ROOT" "$runtime_path" "$AGENT" "$REPOSITORY_PATH" "$SOURCE_REPOSITORY_PATH" "$loader_path" "$agents_path" "$REQUIRE_AGENTS" "$agents_ok"
echo "UEEF active state written: $state_path"
