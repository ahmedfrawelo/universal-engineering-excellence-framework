#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
for f in README.md INSTALL.md QUICK_START.md VERSION.md CHANGELOG.md LICENSE CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md ROADMAP.md BUILD_PROGRESS.md; do
  [ -e "$ROOT/$f" ] || { echo "Missing $f" >&2; exit 1; }
done
for d in framework scripts docs examples tools; do
  [ -d "$ROOT/$d" ] || { echo "Missing $d" >&2; exit 1; }
done
for p in "$ROOT"/framework/[0-9][0-9]-*; do
  [ -f "$p/README.md" ] || { echo "Missing $p/README.md" >&2; exit 1; }
  [ -f "$p/INDEX.md" ] || { echo "Missing $p/INDEX.md" >&2; exit 1; }
done
count="$(find "$ROOT" -name '*.md' -type f | wc -l)"
[ "$count" -ge 160 ] || { echo "Markdown count below minimum: $count" >&2; exit 1; }
if find "$ROOT" -name '*.md' -type f -size 0c | grep .; then echo "Empty Markdown files found" >&2; exit 1; fi
grep -q "00-foundation" "$ROOT/framework/MASTER_INDEX.md"
grep -q "27-quality-gates" "$ROOT/framework/MASTER_INDEX.md"
grep -q "38-templates" "$ROOT/framework/MASTER_INDEX.md"
echo "UEEF validation passed"
echo "Markdown file count: $count"
echo "Framework pack count: $(find "$ROOT/framework" -maxdepth 1 -type d -name '[0-9][0-9]-*' | wc -l)"
echo "Total file count: $(find "$ROOT" -type f | wc -l)"
