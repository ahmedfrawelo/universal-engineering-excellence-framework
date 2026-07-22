#!/usr/bin/env sh
set -eu

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
OPEN_DESIGN_REF=034c3895d127743038c18c09a38eab9c7d6a7641
installer="$CODEX_HOME/skills/.system/skill-installer/scripts/install-skill-from-github.py"
[ -f "$installer" ] || { echo "Skill installer not found: $installer" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 1; }

set --
for path in skills/design-brief skills/frontend-design; do
  name="${path##*/}"
  [ -f "$CODEX_HOME/skills/$name/SKILL.md" ] || set -- "$@" "$path"
done

[ "$#" -gt 0 ] || { echo "Open Design skills already installed"; exit 0; }
python3 "$installer" --repo nexu-io/open-design --ref "$OPEN_DESIGN_REF" --path "$@" --dest "$CODEX_HOME/skills"
echo "Open Design skills installed: $# from $OPEN_DESIGN_REF"
