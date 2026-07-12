#!/usr/bin/env sh
set -eu

REPOSITORY_PATH="${1:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
repo_parent="$(dirname "$REPOSITORY_PATH")"
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

repo_exists=0
exists "$REPOSITORY_PATH" && repo_exists=1
version="UNKNOWN"
if exists "$REPOSITORY_PATH/VERSION.md"; then
  parsed="$(sed -n 's/.*[Vv]ersion:[[:space:]]*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' "$REPOSITORY_PATH/VERSION.md" | sed -n '1p')"
  if [ -n "$parsed" ]; then version="$parsed"; fi
fi

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
activation_gate=0; exists "$REPOSITORY_PATH/framework/27-quality-gates/16-ueef-activation-gate.md" && activation_gate=1
quality_gates=0; exists "$REPOSITORY_PATH/framework/27-quality-gates" && quality_gates=1
validation=0; exists "$REPOSITORY_PATH/scripts/validate-framework.sh" && validation=1
agent_routing=0
if [ -f "$REPOSITORY_PATH/scripts/select-agent-route.ps1" ] && [ -f "$REPOSITORY_PATH/scripts/select-agent-route.sh" ] && [ -f "$REPOSITORY_PATH/UEEF-LOADER.md" ] && grep -q 'reasoningCeiling' "$REPOSITORY_PATH/scripts/select-agent-route.ps1" && grep -q 'noSpawnReason' "$REPOSITORY_PATH/scripts/select-agent-route.sh" && grep -q 'routeEvidenceRequired' "$REPOSITORY_PATH/scripts/select-agent-route.sh" && grep -q 'TOOL_UNAVAILABLE' "$REPOSITORY_PATH/UEEF-LOADER.md" && grep -q 'Agent route:' "$REPOSITORY_PATH/UEEF-LOADER.md" && ! grep -Eq 'reasoning=(high|xhigh|max|ultra)' "$REPOSITORY_PATH/scripts/select-agent-route.sh"; then agent_routing=1; fi
agents_pass=1
active_state_pass=1
old_home_absent=1
if [ "$managed_runtime" = "1" ]; then
  codex_home="$(dirname "$GLOBAL_PATH")"
  agents_path="$codex_home/AGENTS.md"
  state_path="$GLOBAL_PATH/UEEF-ACTIVE.json"
  agents_pass=0
  repository_native="$REPOSITORY_PATH"
  command -v cygpath >/dev/null 2>&1 && repository_native=$(cygpath -w "$REPOSITORY_PATH")
  if [ -f "$agents_path" ] && { grep -Fq "$REPOSITORY_PATH" "$agents_path" || grep -Fq "$repository_native" "$agents_path"; } && grep -q 'TOOL_UNAVAILABLE' "$agents_path" && grep -q 'Agent route:' "$agents_path"; then agents_pass=1; fi
  active_state_pass=0
  if [ -f "$state_path" ] && grep -q '"active"[[:space:]]*:[[:space:]]*true' "$state_path" && grep -q '"agentRoutingContractVersion"[[:space:]]*:[[:space:]]*3' "$state_path" && grep -q '"reasoningCeiling"[[:space:]]*:[[:space:]]*"medium"' "$state_path" && grep -q "\"version\"[[:space:]]*:[[:space:]]*\"$version\"" "$state_path" && grep -q "\"agent\"[[:space:]]*:[[:space:]]*\"$(basename "$REPOSITORY_PATH")\"" "$state_path"; then active_state_pass=1; fi
  if [ -f "$state_path" ] && grep -q '"requireAgents"[[:space:]]*:[[:space:]]*false' "$state_path"; then agents_pass=1; fi
fi
[ -e "$HOME/.ueef" ] && old_home_absent=0
markdown_count=0
if [ "$repo_exists" = "1" ]; then
  markdown_count="$(find "$REPOSITORY_PATH" -path "$REPOSITORY_PATH/.git" -prune -o -name '*.md' -type f -print | wc -l | tr -d ' ')"
fi

global_exists=0; exists "$GLOBAL_PATH" && global_exists=1
loader_count=0
if [ "$global_exists" = "1" ]; then
  loader_count="$(find "$GLOBAL_PATH" -name UEEF-LOADER.md -type f 2>/dev/null | wc -l | tr -d ' ')"
fi
global_loader="UNKNOWN"
if [ "$global_exists" = "1" ] && [ "$loader_count" -gt 0 ]; then global_loader="PASS"; fi
if [ "$global_exists" = "1" ] && [ "$loader_count" -eq 0 ]; then global_loader="FAIL"; fi

installed="NO"
overall="INACTIVE"
if [ "$repo_exists" = "1" ] && [ "$global_exists" = "1" ] && [ "$loader_count" -gt 0 ]; then installed="YES"; fi
if [ "$installed" = "YES" ] && [ "$core_pass" = "1" ] && [ "$master_loader" = "1" ] && [ "$master_index" = "1" ] && [ "$activation_proof" = "1" ] && [ "$activation_gate" = "1" ] && [ "$quality_gates" = "1" ] && [ "$validation" = "1" ] && [ "$agent_routing" = "1" ] && [ "$agents_pass" = "1" ] && [ "$active_state_pass" = "1" ] && [ "$old_home_absent" = "1" ]; then overall="ACTIVE"; fi

printf "%s\n" "UEEF Status"
printf "%s\n" "-----------"
printf "%s\n" "Installed: $installed"
printf "%s\n" "Repository Path: $REPOSITORY_PATH"
printf "%s\n" "Global Path: $GLOBAL_PATH"
printf "%s\n" "Version: $version"
printf "%s\n" "Core files: $(passfail "$core_pass")"
printf "%s\n" "Master loader: $(passfail "$master_loader")"
printf "%s\n" "Master index: $(passfail "$master_index")"
printf "%s\n" "Runtime activation proof: $(passfail "$activation_proof")"
printf "%s\n" "Activation gate: $(passfail "$activation_gate")"
printf "%s\n" "Quality gates: $(passfail "$quality_gates")"
printf "%s\n" "Markdown file count: $markdown_count"
printf "%s\n" "Global loader: $global_loader"
printf "%s\n" "Codex AGENTS: $(passfail "$agents_pass")"
printf "%s\n" "Agent routing contract: $(passfail "$agent_routing")"
printf "%s\n" "Active state: $(passfail "$active_state_pass")"
printf "%s\n" "Old HOME .ueef absent: $(passfail "$old_home_absent")"
if [ "$global_loader" != "PASS" ]; then
  printf "%s\n" "Required action: Run scripts/install-codex.sh, scripts/install-cursor.sh, or scripts/install-generic.sh from Codex with CODEX_HOME set, or set UEEF_GLOBAL_PATH to the Codex runtime path containing UEEF-LOADER.md."
fi
printf "%s\n" "Validation script: $(passfail "$validation")"
printf "%s\n" "Overall: $overall"
