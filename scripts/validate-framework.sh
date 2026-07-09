#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
for f in README.md INSTALL.md VERSION.md framework/MASTER_INDEX.md scripts/install-codex.sh scripts/install-cursor.sh scripts/install-generic.sh; do
  [ -f "$ROOT/$f" ] || { echo "Missing $f" >&2; exit 1; }
done
empty="$(find "$ROOT" -name '*.md' -type f -size 0c)"
if [ -n "$empty" ]; then
  echo "Empty Markdown files: $empty" >&2
  exit 1
fi
if grep -R -i -E 'TODO|FIXME|lorem ipsum|TBD' "$ROOT" --include='*.md'; then
  echo "Disallowed weak marker found" >&2
  exit 1
fi
grep -q "Core Constitution" "$ROOT/framework/MASTER_INDEX.md"
grep -q "React Pack" "$ROOT/framework/MASTER_INDEX.md"
grep -q "Quality Gates" "$ROOT/framework/MASTER_INDEX.md"
echo "UEEF validation passed"
echo "Markdown file count: $(find "$ROOT" -name '*.md' -type f | wc -l)"
echo "Total file count: $(find "$ROOT" -type f | wc -l)"
