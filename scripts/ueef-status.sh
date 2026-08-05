#!/usr/bin/env sh
set -eu

REPOSITORY_PATH="${1:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
[ -d "$REPOSITORY_PATH" ] || { echo "Repository path does not exist: $REPOSITORY_PATH" >&2; exit 2; }
REPOSITORY_PATH=$(CDPATH= cd -- "$REPOSITORY_PATH" && pwd -P)
repo_parent=$(dirname "$REPOSITORY_PATH")
managed_runtime=0
[ "$(basename "$repo_parent")" = "ueef" ] && managed_runtime=1

if [ -n "${UEEF_GLOBAL_PATH:-}" ]; then
  GLOBAL_PATH="$UEEF_GLOBAL_PATH"
elif [ "$managed_runtime" = "1" ]; then
  GLOBAL_PATH="$repo_parent"
elif [ -n "${CODEX_HOME:-}" ]; then
  GLOBAL_PATH="$CODEX_HOME/ueef"
else
  GLOBAL_PATH="$(dirname "$REPOSITORY_PATH")/ueef-runtime"
fi

exists() { [ -e "$1" ]; }
passfail() { if [ "$1" = "1" ]; then printf "PASS"; else printf "FAIL"; fi; }

repo_exists=1
version="UNKNOWN"
if exists "$REPOSITORY_PATH/VERSION.md"; then
  parsed=$(sed -n 's/.*[Vv]ersion:[[:space:]]*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' "$REPOSITORY_PATH/VERSION.md" | sed -n '1p')
  [ -n "$parsed" ] && version="$parsed"
fi

root_pass=1
for f in README.md INSTALL.md QUICK_START.md BUILD_PROGRESS.md; do
  exists "$REPOSITORY_PATH/$f" || root_pass=0
done
core_pass=1
for f in \
  framework/01-core/00-core-system.md \
  framework/01-core/01-master-loader.md \
  framework/01-core/02-master-index.md \
  framework/01-core/10-runtime-activation-proof.md \
  framework/01-core/11-ueef-status-check.md \
  framework/01-core/12-ueef-required-preflight.md
do
  exists "$REPOSITORY_PATH/$f" || core_pass=0
done

master_loader=0; exists "$REPOSITORY_PATH/framework/01-core/01-master-loader.md" && master_loader=1
master_index=0; { exists "$REPOSITORY_PATH/framework/01-core/02-master-index.md" || exists "$REPOSITORY_PATH/framework/MASTER_INDEX.md"; } && master_index=1
activation_proof=0; exists "$REPOSITORY_PATH/framework/01-core/10-runtime-activation-proof.md" && activation_proof=1
activation_gate=0; exists "$REPOSITORY_PATH/framework/12-delivery-quality/04-quality-gates/16-ueef-activation-gate.md" && activation_gate=1
quality_gates=0; exists "$REPOSITORY_PATH/framework/12-delivery-quality/04-quality-gates" && quality_gates=1
validation=0; exists "$REPOSITORY_PATH/scripts/validate-framework.sh" && validation=1
agent_routing=0
if [ -f "$REPOSITORY_PATH/scripts/select-agent-route.ps1" ] && [ -f "$REPOSITORY_PATH/scripts/select-agent-route.sh" ] && [ -f "$REPOSITORY_PATH/UEEF-LOADER.md" ] && grep -q 'reasoningCeiling' "$REPOSITORY_PATH/scripts/select-agent-route.ps1" && grep -q 'noSpawnReason' "$REPOSITORY_PATH/scripts/select-agent-route.sh" && grep -q 'routeEvidenceRequired' "$REPOSITORY_PATH/scripts/select-agent-route.sh" && grep -q 'TOOL_UNAVAILABLE' "$REPOSITORY_PATH/UEEF-LOADER.md" && grep -q 'Agent route:' "$REPOSITORY_PATH/UEEF-LOADER.md" && grep -q 'proportional' "$REPOSITORY_PATH/scripts/select-agent-route.ps1"; then agent_routing=1; fi
repository_intelligence=1
for f in framework/20-repository-evolution/03-repository-intelligence/00-repository-intelligence-system.md scripts/repository-intelligence.ps1 scripts/repository-intelligence.sh config/repository-intelligence-policy.json engines/repository-intelligence/UEEF-UPSTREAM.json engines/repository-intelligence/UPSTREAM-FILES.json; do
  exists "$REPOSITORY_PATH/$f" || repository_intelligence=0
done

source_validation=0
if [ "$root_pass" = "1" ] && [ "$core_pass" = "1" ] && [ "$master_loader" = "1" ] && [ "$master_index" = "1" ] && [ "$activation_proof" = "1" ] && [ "$activation_gate" = "1" ] && [ "$quality_gates" = "1" ] && [ "$validation" = "1" ] && [ "$agent_routing" = "1" ] && [ "$repository_intelligence" = "1" ]; then source_validation=1; fi

agents_pass=1
active_state_pass=1
managed_enforcement_pass=1
runtime_drift_pass=1
runtime_drift_status="NOT_APPLICABLE"
source_revision_status="SKIPPED"
old_home_absent=1
old_home_status="NOT_APPLICABLE"
global_loader="NOT_APPLICABLE"
installed="NO"

if [ "$managed_runtime" = "1" ]; then
  codex_home=$(dirname "$GLOBAL_PATH")
  agents_path="$codex_home/AGENTS.md"
  state_path="$GLOBAL_PATH/UEEF-ACTIVE.json"
  agents_pass=0
  repository_native="$REPOSITORY_PATH"
  command -v cygpath >/dev/null 2>&1 && repository_native=$(cygpath -w "$REPOSITORY_PATH")
  if [ -f "$agents_path" ] && { grep -Fq "$REPOSITORY_PATH" "$agents_path" || grep -Fq "$repository_native" "$agents_path"; } && grep -Eq 'T0/T1 stay single-agent|T1 defaults to single-agent' "$agents_path" && grep -q 'route rationale' "$agents_path" && grep -Fq "(version $version)" "$agents_path"; then agents_pass=1; fi

  active_state_pass=0
  managed_enforcement_pass=0
  runtime_agent=$(basename "$REPOSITORY_PATH")
  expected_runtime_path="$REPOSITORY_PATH"
  expected_loader_path="$REPOSITORY_PATH/UEEF-LOADER.md"
  if command -v cygpath >/dev/null 2>&1; then
    expected_runtime_path=$(cygpath -w "$expected_runtime_path")
    expected_loader_path=$(cygpath -w "$expected_loader_path")
  fi
  if [ -f "$state_path" ] && node "$REPOSITORY_PATH/scripts/active-state.mjs" validate "$state_path" "$version" "$runtime_agent" "$expected_runtime_path" "$expected_loader_path" >/dev/null; then active_state_pass=1; fi
  if [ -f "$state_path" ] && node "$REPOSITORY_PATH/scripts/active-state.mjs" validate-managed "$state_path" "$expected_runtime_path" >/dev/null; then managed_enforcement_pass=1; fi
  require_agents=$(node "$REPOSITORY_PATH/scripts/active-state.mjs" require-agents "$state_path" 2>/dev/null || printf true)
  if [ "$require_agents" = false ]; then
    case "$runtime_agent" in [Cc][Oo][Dd][Ee][Xx]) : ;; *) agents_pass=1 ;; esac
  fi

  runtime_drift_pass=0
  runtime_drift_status="FAIL"
  source_repository=$(node "$REPOSITORY_PATH/scripts/active-state.mjs" source "$state_path" 2>/dev/null || true)
  if command -v cygpath >/dev/null 2>&1 && [ -n "$source_repository" ]; then source_repository=$(cygpath -u "$source_repository"); fi
  if [ -d "$source_repository" ] && node "$REPOSITORY_PATH/scripts/check-runtime-drift.mjs" "$source_repository" "$REPOSITORY_PATH" >/dev/null 2>&1; then
    runtime_drift_pass=1
    runtime_drift_status="PASS"
  fi

  if [ -f "$state_path" ] && [ -d "$source_repository" ]; then
    recorded_commit=$(node -e 'const fs=require("fs");const s=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(s.sourceCommit||""));' "$state_path" 2>/dev/null || true)
    current_commit=$(git -c "safe.directory=$source_repository" -C "$source_repository" rev-parse HEAD 2>/dev/null || true)
    if [ -n "$recorded_commit" ] && [ "$recorded_commit" != "UNKNOWN" ] && [ -n "$current_commit" ]; then
      if [ "$recorded_commit" = "$current_commit" ]; then source_revision_status="PASS"; else source_revision_status="WARN_OUTDATED"; fi
    fi
  fi

  [ -e "$HOME/.ueef" ] && old_home_absent=0
  old_home_status=$(passfail "$old_home_absent")
  if [ -d "$GLOBAL_PATH" ]; then
    if [ -f "$REPOSITORY_PATH/UEEF-LOADER.md" ]; then global_loader="PASS"; else global_loader="FAIL"; fi
  else
    global_loader="UNKNOWN"
  fi
  if [ -d "$REPOSITORY_PATH" ] && [ -d "$GLOBAL_PATH" ] && [ "$global_loader" = "PASS" ]; then installed="YES"; fi
fi

markdown_count=$(find "$REPOSITORY_PATH" -path "$REPOSITORY_PATH/.git" -prune -o -path "$REPOSITORY_PATH/engines/repository-intelligence/.venv" -prune -o -path "$REPOSITORY_PATH/engines/repository-intelligence/__pycache__" -prune -o -path "$REPOSITORY_PATH/engines/repository-intelligence/.pytest_cache" -prune -o -path "$REPOSITORY_PATH/engines/repository-intelligence/.hypothesis" -prune -o -path "$REPOSITORY_PATH/engines/repository-intelligence/.ruff_cache" -prune -o -path "$REPOSITORY_PATH/engines/repository-intelligence/.mypy_cache" -prune -o -name '*.md' -type f -print | wc -l | tr -d ' ')
overall="SOURCE_INVALID"
mode="source-checkout"
agents_status="NOT_APPLICABLE"
active_state_status="NOT_APPLICABLE"
if [ "$managed_runtime" = "1" ]; then
  mode="managed-runtime"
  agents_status=$(passfail "$agents_pass")
  active_state_status=$(passfail "$active_state_pass")
  overall="INACTIVE"
  if [ "$installed" = "YES" ] && [ "$source_validation" = "1" ] && [ "$agents_pass" = "1" ] && [ "$active_state_pass" = "1" ] && [ "$managed_enforcement_pass" = "1" ] && [ "$runtime_drift_pass" = "1" ] && [ "$old_home_absent" = "1" ]; then overall="ACTIVE"; fi
elif [ "$source_validation" = "1" ]; then
  overall="SOURCE_VALIDATED"
fi

printf '%s\n' "UEEF Status"
printf '%s\n' "-----------"
printf '%s\n' "Installed: $installed"
printf '%s\n' "Repository Path: $REPOSITORY_PATH"
printf '%s\n' "Global Path: $GLOBAL_PATH"
printf '%s\n' "Version: $version"
printf '%s\n' "Mode: $mode"
printf '%s\n' "Source validation: $(passfail "$source_validation")"
printf '%s\n' "Core files: $(passfail "$core_pass")"
printf '%s\n' "Master loader: $(passfail "$master_loader")"
printf '%s\n' "Master index: $(passfail "$master_index")"
printf '%s\n' "Runtime activation proof: $(passfail "$activation_proof")"
printf '%s\n' "Activation gate: $(passfail "$activation_gate")"
printf '%s\n' "Quality gates: $(passfail "$quality_gates")"
printf '%s\n' "Markdown file count: $markdown_count"
printf '%s\n' "Global loader: $global_loader"
printf '%s\n' "Codex AGENTS: $agents_status"
printf '%s\n' "Agent routing contract: $(passfail "$agent_routing")"
printf '%s\n' "Repository intelligence: $(passfail "$repository_intelligence")"
printf '%s\n' "Active state: $active_state_status"
printf '%s\n' "Managed enforcement: $(if [ "$managed_runtime" = "1" ]; then passfail "$managed_enforcement_pass"; else printf 'NOT_APPLICABLE'; fi)"
printf '%s\n' "Runtime drift: $runtime_drift_status"
printf '%s\n' "Runtime source revision: $source_revision_status"
printf '%s\n' "Old HOME .ueef absent: $old_home_status"
if [ "$managed_runtime" = "1" ] && [ "$global_loader" != "PASS" ]; then
  printf '%s\n' "Required action: Run scripts/install-codex.sh, scripts/install-cursor.sh, or scripts/install-generic.sh from Codex with CODEX_HOME set, or set UEEF_GLOBAL_PATH to the Codex runtime path containing UEEF-LOADER.md."
fi
if [ "$managed_runtime" = "0" ] && [ "$overall" = "SOURCE_VALIDATED" ]; then
  printf '%s\n' "Source checkout validated. Activation is not claimed until the source is synchronized into a managed runtime."
fi
printf '%s\n' "Validation script: $(passfail "$validation")"
printf '%s\n' "Overall: $overall"
