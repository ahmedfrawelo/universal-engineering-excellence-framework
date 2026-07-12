#!/usr/bin/env sh
set -eu

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
installer="$CODEX_HOME/skills/.system/skill-installer/scripts/install-skill-from-github.py"
[ -f "$installer" ] || { echo "Skill installer not found: $installer" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 1; }

set --
for path in \
  skills/animation-vocabulary \
  skills/apple-design \
  skills/emil-design-eng \
  skills/improve-animations \
  skills/review-animations; do
  name="${path##*/}"
  [ -f "$CODEX_HOME/skills/$name/SKILL.md" ] || set -- "$@" "$path"
done

[ "$#" -gt 0 ] || { echo "Design engineering skills already installed"; exit 0; }
python3 "$installer" --repo emilkowalski/skills --path "$@" --dest "$CODEX_HOME/skills"
echo "Design engineering skills installed: $#"
