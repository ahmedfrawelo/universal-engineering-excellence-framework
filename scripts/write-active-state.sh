#!/usr/bin/env sh
set -eu

REPOSITORY_PATH=${1:?repository path required}
RUNTIME_ROOT=${2:?runtime root required}
AGENT=${3:?agent required}
SOURCE_REPOSITORY_PATH=${4:-$REPOSITORY_PATH}
CODEX_HOME=${5:-$(dirname "$RUNTIME_ROOT")}
REQUIRE_AGENTS=${6:-0}

escape_json() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
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
temp_path="$state_path.tmp.$$"
cat > "$temp_path" <<EOF
{
  "active": true,
  "agentRoutingContractVersion": 2,
  "reasoningCeiling": "medium",
  "version": "$(escape_json "$version")",
  "codexHome": "$(escape_json "$CODEX_HOME")",
  "runtimeRoot": "$(escape_json "$RUNTIME_ROOT")",
  "runtimePath": "$(escape_json "$runtime_path")",
  "agent": "$(escape_json "$AGENT")",
  "repositoryPath": "$(escape_json "$REPOSITORY_PATH")",
  "sourceRepositoryPath": "$(escape_json "$SOURCE_REPOSITORY_PATH")",
  "loaderPath": "$(escape_json "$loader_path")",
  "agentsPath": "$(escape_json "$agents_path")",
  "requireAgents": $([ "$REQUIRE_AGENTS" = 1 ] && printf true || printf false),
  "requiredChecks": {"loader":true,"agents":$agents_ok,"coreSystem":true,"masterLoader":true,"masterIndex":true,"activationGate":true,"statusScript":true}
}
EOF
mv "$temp_path" "$state_path"
echo "UEEF active state written: $state_path"
