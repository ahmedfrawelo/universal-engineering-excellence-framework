#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CODEX_HOME=${CODEX_HOME:-$HOME/.codex}
if [ -n "${UEEF_PROFILES:-}" ]; then
  PROFILES="$UEEF_PROFILES"
else
  PROFILES="Core,AI"
  if find "$ROOT" -type f \( -name package.json -o -name angular.json -o -name '*.tsx' -o -name '*.jsx' -o -name '*.vue' -o -name '*.svelte' \) -not -path '*/.git/*' | grep -q .; then PROFILES="$PROFILES,Frontend,UIUX"; fi
  if find "$ROOT" -type f \( -name '*.sln' -o -name '*.csproj' -o -name pyproject.toml -o -name requirements.txt -o -name pom.xml -o -name Dockerfile \) -not -path '*/.git/*' | grep -q .; then PROFILES="$PROFILES,Backend"; fi
  if find "$ROOT" -type f \( -name '*.sql' -o -iname '*migration*' -o -iname '*prisma*' \) -not -path '*/.git/*' | grep -q .; then PROFILES="$PROFILES,Database"; fi
  if [ -d "$ROOT/.github/workflows" ] || find "$ROOT" -maxdepth 2 -type f \( -name Dockerfile -o -name 'docker-compose*' -o -name Jenkinsfile \) | grep -q .; then PROFILES="$PROFILES,DevOps"; fi
fi
status=0
check_cmd(){ command -v "$1" >/dev/null 2>&1; }
check_path(){ [ -n "$1" ] && [ -f "$1" ]; }
has_profile(){ case ",$PROFILES," in *",$1,"*) return 0;; *) return 1;; esac; }
echo "Environment Profile"
echo "Profiles Loaded: $PROFILES"
echo "Core"
for cmd in git gh; do if check_cmd "$cmd"; then echo "$cmd PASS"; else echo "$cmd MISSING (Mandatory)"; status=2; fi; done
if check_path "$CODEX_HOME/ueef/codex/UEEF-LOADER.md"; then echo "UEEF Runtime PASS"; else echo "UEEF Runtime MISSING (Mandatory)"; status=2; fi
if [ -f "$ROOT/scripts/validate-framework.ps1" ]; then echo "Validation Scripts PASS"; else echo "Validation Scripts MISSING (Mandatory)"; status=2; fi
for skill in skill-installer openai-docs skill-creator; do if check_path "$CODEX_HOME/skills/.system/$skill/SKILL.md"; then echo "$skill PASS"; else echo "$skill MISSING (Mandatory)"; status=2; fi; done
echo "AI"
if check_path "$CODEX_HOME/AGENTS.md"; then echo "Runtime Loader PASS"; else echo "Runtime Loader MISSING (Mandatory)"; status=2; fi
if has_profile Frontend; then echo "Frontend SELECTED"; else echo "Frontend NOT REQUIRED"; fi
if has_profile Backend; then echo "Backend SELECTED"; else echo "Backend NOT REQUIRED"; fi
if has_profile Database; then echo "Database SELECTED"; else echo "Database NOT REQUIRED"; fi
if has_profile UIUX; then
  echo "UIUX SELECTED"
  if check_path "$CODEX_HOME/skills/ui-ux-pro-max/SKILL.md"; then echo "ui-ux-pro-max PASS"; else echo "ui-ux-pro-max MISSING (Mandatory)"; status=2; fi
  if check_path "$CODEX_HOME/skills/impeccable/SKILL.md"; then echo "impeccable PASS"; else echo "impeccable MISSING (Mandatory)"; status=2; fi
else echo "UIUX NOT REQUIRED"; fi
if has_profile DevOps; then echo "DevOps SELECTED"; else echo "DevOps NOT REQUIRED"; fi
echo "Optional CONTINUE"
if [ "$status" -eq 2 ]; then echo "Overall BLOCKED"; exit 2; fi
echo "Overall READY"
