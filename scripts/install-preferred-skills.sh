#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CODEX_HOME_PATH=${CODEX_HOME:-"$HOME/.codex"}
MANIFEST="$ROOT/config/preferred-skills.json"
INSTALLER="$CODEX_HOME_PATH/skills/.system/skill-installer/scripts/install-skill-from-github.py"
DESTINATION="$CODEX_HOME_PATH/skills"

[ -f "$MANIFEST" ] || { echo "Preferred skills manifest not found: $MANIFEST" >&2; exit 2; }
[ -f "$INSTALLER" ] || { echo "Skill installer not found: $INSTALLER" >&2; exit 2; }
command -v node >/dev/null 2>&1 || { echo "Node.js is required to read the preferred skills manifest." >&2; exit 2; }
if command -v python3 >/dev/null 2>&1; then PYTHON=python3
elif command -v python >/dev/null 2>&1; then PYTHON=python
else echo "Python was not found." >&2; exit 2
fi

mkdir -p "$DESTINATION"
requested=" $* "
known=$(node -e 'const m=require(process.argv[1]);process.stdout.write(m.preferred.map(x=>x.id).join(" "));' "$MANIFEST")
for wanted in "$@"; do
  case " $known " in *" $wanted "*) : ;; *) echo "Unknown preferred skill: $wanted" >&2; exit 2 ;; esac
done

node -e 'const m=require(process.argv[1]);for(const x of m.preferred)console.log([x.id,x.source.repository,x.source.ref,x.source.path,x.source.installName||x.id].join("\t"));' "$MANIFEST" |
while IFS="$(printf '\t')" read -r id repository ref skill_path install_name; do
  if [ "$#" -gt 0 ]; then
    case "$requested" in *" $id "*) : ;; *) continue ;; esac
  fi
  skill_root="$DESTINATION/$id"
  if [ -f "$skill_root/SKILL.md" ]; then
    printf '%s\n' "$id ALREADY_INSTALLED"
    continue
  fi
  [ ! -e "$skill_root" ] || { echo "Refusing to overwrite incomplete skill directory: $skill_root" >&2; exit 1; }
  "$PYTHON" "$INSTALLER" --repo "$repository" --ref "$ref" --path "$skill_path" --name "$install_name" --dest "$DESTINATION"
  [ -f "$skill_root/SKILL.md" ] || { echo "Installer completed without creating $skill_root/SKILL.md" >&2; exit 1; }
  printf '%s\n' "$id INSTALLED"
done
