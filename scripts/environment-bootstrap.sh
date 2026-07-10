#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
status=0
check_cmd(){ command -v "$1" >/dev/null 2>&1; }
echo "Environment Profile"
echo "Core"
for cmd in git gh; do if check_cmd "$cmd"; then echo "$cmd PASS"; else echo "$cmd MISSING (Mandatory)"; status=2; fi; done
if [ -f "${CODEX_HOME:-$HOME/.codex}/ueef/codex/UEEF-LOADER.md" ]; then echo "UEEF Runtime PASS"; else echo "UEEF Runtime MISSING (Mandatory)"; status=2; fi
if [ -f "$ROOT/scripts/validate-framework.ps1" ]; then echo "Validation Scripts PASS"; else echo "Validation Scripts MISSING (Mandatory)"; status=2; fi
echo "AI"
if [ -f "${CODEX_HOME:-$HOME/.codex}/AGENTS.md" ]; then echo "Runtime Loader PASS"; else echo "Runtime Loader MISSING (Mandatory)"; status=2; fi
echo "Frontend NOT REQUIRED unless detected"
echo "Backend NOT REQUIRED unless detected"
echo "Database NOT REQUIRED unless detected"
echo "UIUX NOT REQUIRED unless detected"
echo "DevOps NOT REQUIRED unless detected"
echo "Optional CONTINUE"
if [ "$status" -eq 2 ]; then echo "Overall BLOCKED"; exit 2; fi
echo "Overall READY"
